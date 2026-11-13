extends CanvasLayer
## The spotlight (review page A3kZBgNsSHBe45J16ukSkd, cards C4 and C5, approved November 13,
## 2026): one stone given the whole screen. The table dims, the stone turns big on the lamp
## with rays of its grade's color behind it, its name lands, then its grade is stamped on.
## A new skill says which slot of the vault it lights; a stone that beats the one kept says by
## how much; the best of a haul says what records it sets.
##
## On the haul's table it is one of a few in a row: a click, Space or Enter moves on, Escape
## closes the rest (`done` tells which). Where one stone is the whole story (a Geode cracked at
## the Market, a contract's stone) it carries that stone's fates as buttons instead, the way the
## table's pane does: one click each, the one that would give up the finer stone drawn in red.

const GemView = preload("res://view/gems/gem_view.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")

## "next" (moved on), "skip" (Escape: the rest are closed too) or "action".
signal done(how: String)

## The desk's stage for the stone, and the phone's (in points).
const STAGE := 330.0
const PHONE_STAGE := 176.0

static var _open: CanvasLayer = null

var stone: Dictionary = {}
var opts: Dictionary = {}
var actions: Array = []
var _root: Control
var _dim: ColorRect
var _rays: Control
var _lamp: TextureRect
var _stage: Control
var _view: Control
var _head: Label
var _stamp: Control
var _foot: Control
var _tone: Color = Color.WHITE
var _closing: bool = false
var _shown_at: int = 0

static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)

static func show_stone(shown: Dictionary, options: Dictionary = {}) -> CanvasLayer:
	## Puts a stone in the spotlight. `options`: kind ("new", "best", "upgrade", "find"), owned
	## (the stone of its skill kept, to weigh it against), slot ([kept, of] of its color before
	## it, and vault [kept, of]), records ([glyph, words] ribbons), index and count (its place in
	## the row), actions (fates, for a stone shown on its own), low (a fall's lower key). Null
	## without a display; the caller goes on as if it had been closed.
	if DisplayServer.get_name() == "headless":
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if is_open():
		_open.queue_free()
	Inspector.close()
	var made: CanvasLayer = load("res://view/gems/spotlight.gd").new()
	tree.root.add_child(made)
	made.call("build", shown, options)
	made.call("play")
	_open = made
	return made

func build(shown: Dictionary, options: Dictionary) -> void:
	layer = 63
	stone = shown.duplicate(true)
	stone.appraised = true
	stone.inclusions_revealed = true
	opts = options
	actions = options.get("actions", [])
	var grade: Dictionary = DeepStone.grade(stone)
	_tone = DeepUi.tier_color(str(grade.tier))
	_root = Control.new()
	DeepUi.use_theme(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	## Opaque enough that nothing on the table behind reads through it (Q2).
	_dim.color = Color(0.004, 0.005, 0.015, 1.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_clicked)
	_root.add_child(_dim)
	_rays = Inspector.Rays.new(_tone)
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.modulate.a = 0.0
	_root.add_child(_rays)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DeepUi.phone:
		frame.add_theme_constant_override("margin_left", int(DeepUi.safe_left + DeepUi.pt(8)))
		frame.add_theme_constant_override("margin_right", int(DeepUi.safe_right + DeepUi.pt(8)))
		frame.add_theme_constant_override("margin_top", int(DeepUi.safe_top + DeepUi.pt(8)))
		frame.add_theme_constant_override("margin_bottom", int(DeepUi.safe_bottom + DeepUi.pt(6)))
	else:
		for side in ["left", "right"]:
			frame.add_theme_constant_override("margin_" + side, 60)
		frame.add_theme_constant_override("margin_top", 44)
		frame.add_theme_constant_override("margin_bottom", 34)
	_root.add_child(frame)
	if DeepUi.phone:
		_build_phone(frame, grade)
	else:
		_build_desk(frame, grade)

func _headline() -> Array:
	## What the spotlight shouts over the stone: [words, tone, the line under it].
	var name: String = DeepUi.skill_name(stone)
	match str(opts.get("kind", "find")):
		"best":
			return ["Best of the haul", DeepUi.ACCENT_HI, ("And a new skill: the first %s to come home" % name) if bool(opts.get("fresh", false)) else "The finest stone this run brought home"]
		"new":
			return ["A new skill!", DeepUi.ACCENT_HI.lerp(Color("7fe0ff"), 0.85), "The first %s to come home" % name]
		"upgrade":
			return ["An upgrade", DeepUi.GOOD, "Better than the %s in your vault" % name]
	var owned: Dictionary = opts.get("owned", {})
	if owned.is_empty():
		return ["A new skill!", Color("7fe0ff"), "The first %s you have found" % name]
	if DeepProfile.better_stone(stone, owned):
		return ["An upgrade", DeepUi.GOOD, "Better than the %s in your vault" % name]
	return ["Out of the rock", _tone.lightened(0.2), "Yours is the finer %s" % name]

func _build_desk(frame: MarginContainer, grade: Dictionary) -> void:
	var column := DeepUi.vbox(frame, 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var said: Array = _headline()
	_head = DeepUi.title(column, str(said[0]), 56, said[1], HORIZONTAL_ALIGNMENT_CENTER)
	_head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_head.add_theme_constant_override("outline_size", 12)
	DeepUi.label(column, str(said[2]), 17, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var row := DeepUi.hbox(column, 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## A gap as wide as the side card on the left, so the stone stands in the middle.
	DeepUi.gap(row, 330.0)
	var middle := DeepUi.vbox(row, 6)
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage_in(middle, STAGE)
	_words(middle, grade, 50, 15, 36)
	var side := DeepUi.card(row, Color(DeepUi.LINE, 0.9), 18, Color(0.05, 0.065, 0.11, 0.9))
	side.custom_minimum_size.x = 330.0
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_side(DeepUi.vbox(side, 10), 15)
	_foot = DeepUi.vbox(column, 6)
	_foot.custom_minimum_size.y = 70.0
	_fill_foot(_foot, 17)

func _build_phone(frame: MarginContainer, grade: Dictionary) -> void:
	var row := DeepUi.hbox(frame, int(DeepUi.pt(16)))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var left := DeepUi.vbox(row, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage_in(left, DeepUi.pt(PHONE_STAGE))
	var right := DeepUi.vbox(row, int(DeepUi.pt(4)))
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size.x = DeepUi.pt(380)
	var said: Array = _headline()
	_head = DeepUi.title(right, str(said[0]), 28, said[1])
	_head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_head.add_theme_constant_override("outline_size", 8)
	_words(right, grade, 32, 12, 24, false)
	_side(DeepUi.vbox(right, int(DeepUi.pt(3))), 12)
	_foot = DeepUi.vbox(right, int(DeepUi.pt(3)))
	_fill_foot(_foot, 13)

func _stage_in(parent: Control, edge: float) -> void:
	## The stone itself, turning in a pool of its grade's light.
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(edge, edge)
	_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_stage)
	_lamp = DeepUi.glow(_stage, _tone, 0.55, 1.5)
	_view = GemView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_slot(edge * 0.72)
	_view.set_drift(true)
	_view.set_spin(0.6)
	_view.configure(stone)
	_stage.add_child(_view)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _words(parent: Control, grade: Dictionary, name_size: int, tag_size: int, stamp_size: int, centred: bool = true) -> void:
	## Its name in its own color, what it is, and the grade stamped under it.
	var align: int = HORIZONTAL_ALIGNMENT_CENTER if centred else HORIZONTAL_ALIGNMENT_LEFT
	DeepUi.title(parent, DeepUi.skill_name(stone), name_size, GemMesh.tint(stone).lightened(0.35), align)
	var tags := DeepUi.hbox(parent, 6)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER if centred else BoxContainer.ALIGNMENT_BEGIN
	StoneCard.rarity_tag(tags, str(DeepStone.skill_of(stone).get("rarity", "COMMON")), tag_size, false)
	DeepUi.chip(tags, StoneCard.color_words(stone), DeepUi.color(DeepStone.color(stone)), tag_size, DeepUi.is_rainbow(DeepStone.color(stone)))
	DeepUi.chip(tags, "%d ct · %s · %s" % [int(stone.get("carat", 1)), DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.clarity_name(int(stone.get("clarity", 3)))], DeepUi.MUTED, tag_size)
	var holder := DeepUi.hbox(parent, 0)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER if centred else BoxContainer.ALIGNMENT_BEGIN
	_stamp = DeepUi.pill(holder, "star", "%d · %s" % [int(grade.score), str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier))], _tone, stamp_size, "Grade %d of 100" % int(grade.score))
	_stamp.modulate.a = 0.0

func _side(box: VBoxContainer, size: int) -> void:
	## Beside the stone: the slot a new skill lights, or how it weighs against the one kept; and
	## any record it sets.
	var owned: Dictionary = opts.get("owned", {})
	var slot: Dictionary = opts.get("slot", {})
	if owned.is_empty() and not slot.is_empty():
		DeepUi.heading(box, "Fills a slot", size - 2, DeepUi.ACCENT)
		var color: String = DeepStone.color(stone)
		var have: Array = slot.get("color", [0, 1])
		var hue: Color = DeepUi.color(color)
		DeepUi.title(box, "%s · %d of %d" % [str(DeepContent.color(color).get("name", color.capitalize())), int(have[0]) + 1, maxi(1, int(have[1]))], size + 5, hue.lightened(0.25))
		var meter := DeepUi.bar(box, DeepUi.pt(6) if DeepUi.phone else 8.0, hue, Color(DeepUi.INK, 0.9))
		meter.custom_minimum_size.x = DeepUi.pt(180) if DeepUi.phone else 260.0
		meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		meter.call("set_values", float(int(have[0]) + 1) / float(maxi(1, int(have[1]))))
		var vault: Array = slot.get("vault", [0, 1])
		DeepUi.label(box, "Vault %d of %d" % [int(vault[0]) + 1, int(vault[1])], size, DeepUi.MUTED)
	elif not owned.is_empty():
		DeepUi.heading(box, "Against yours", size - 2, DeepUi.ACCENT)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", int(DeepUi.pt(10)) if DeepUi.phone else 18)
		grid.add_theme_constant_override("v_separation", 2)
		box.add_child(grid)
		var found: Dictionary = DeepStone.grade(stone)
		var kept: Dictionary = DeepStone.grade(owned)
		for row in [["", "Found", "Yours", 0], ["Carat", "%d ct" % int(stone.get("carat", 1)), "%d ct" % int(owned.get("carat", 1)), int(stone.get("carat", 1)) - int(owned.get("carat", 1))],
				["Cut", DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.cut_name(int(owned.get("cut", 0))), int(stone.get("cut", 0)) - int(owned.get("cut", 0))],
				["Grade", str(int(found.score)), str(int(kept.score)), int(found.score) - int(kept.score)],
				["Worth", str(DeepStone.value(stone)), str(DeepStone.value(owned)), DeepStone.value(stone) - DeepStone.value(owned)]]:
			var head: bool = str(row[0]).is_empty()
			DeepUi.label(grid, str(row[0]), size - 1, DeepUi.MUTED)
			var mine := DeepUi.label(grid, str(row[1]), size - (2 if head else 0), DeepUi.DIM if head else (DeepUi.GOOD if int(row[3]) > 0 else DeepUi.PAPER))
			var theirs := DeepUi.label(grid, str(row[2]), size - (2 if head else 0), DeepUi.DIM if head else (DeepUi.GOOD if int(row[3]) < 0 else DeepUi.MUTED))
			if not head:
				mine.add_theme_font_override("font", DeepUi.bold_font())
				theirs.add_theme_font_override("font", DeepUi.bold_font())
	for entry in opts.get("records", []):
		DeepUi.pill(box, str(entry[0]), str(entry[1]), DeepUi.ACCENT_HI, size - 1).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func _fill_foot(foot: VBoxContainer, size: int) -> void:
	## The way on: a line saying how many are left, or the stone's fates.
	if actions.is_empty():
		var count: int = int(opts.get("count", 1))
		var words: String = ("Tap anywhere for the next" if DeepUi.phone else "Click or press Space for the next") if int(opts.get("index", 0)) + 1 < count else ("Tap anywhere to go on" if DeepUi.phone else "Click or press Space to go on")
		if count > 1:
			words += " · %d of %d" % [int(opts.get("index", 0)) + 1, count]
		var line := DeepUi.label(foot, words, size, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT if DeepUi.phone else HORIZONTAL_ALIGNMENT_CENTER)
		line.modulate.a = 0.85
		if count > 1 and int(opts.get("index", 0)) + 1 < count and not DeepUi.phone:
			DeepUi.label(foot, "Esc skips the rest", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var row := DeepUi.hbox(foot, int(DeepUi.pt(6)) if DeepUi.phone else 14)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if DeepUi.phone else BoxContainer.ALIGNMENT_CENTER
	for action in actions:
		_action_button(row, action, size)

func _action_button(row: HBoxContainer, action: Dictionary, size: int) -> void:
	## One fate as a button: filled when it is the suggested one, outlined otherwise, and red
	## when it would give up the finer stone (said under it; one click all the same).
	var box := DeepUi.vbox(row, int(DeepUi.pt(2)) if DeepUi.phone else 4)
	var tone: Color = action.get("tone", DeepUi.ACCENT)
	var risky: bool = bool(action.get("risky", false))
	var button: Button
	var press := func() -> void: _choose(action)
	if bool(action.get("main", false)) and not risky:
		button = DeepUi.primary(box, str(action.get("glyph", "check")), str(action.get("label", "")), press, size, DeepUi.coin_safe(tone))
	else:
		button = DeepUi.icon_button(box, str(action.get("glyph", "check")), str(action.get("label", "")), press, size - 1, DeepUi.BAD if risky else (DeepUi.MUTED if bool(action.get("dismiss", false)) else tone))
		var edge: Color = DeepUi.BAD if risky else Color(tone, 0.8)
		button.add_theme_stylebox_override("normal", DeepUi.button_style(DeepUi.SLATE, edge, 12))
		button.add_theme_stylebox_override("hover", DeepUi.button_style(DeepUi.SLATE_HI, edge.lightened(0.3), 12))
	button.custom_minimum_size = Vector2(DeepUi.pt(96), DeepUi.pt(44)) if DeepUi.phone else Vector2(200, 50)
	if not str(action.get("price", "")).is_empty():
		DeepUi.priced(button, str(action.price))
	if action.has("sound"):
		DeepUi.voice(button, str(action.sound))
	var caption: String = "Gives up the finer stone" if risky else str(action.get("caption", ""))
	if not caption.is_empty():
		var said := DeepUi.label(box, caption, 11 if DeepUi.phone else 12, DeepUi.BAD if risky else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		said.custom_minimum_size.x = button.custom_minimum_size.x
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func play() -> void:
	## The dark comes down, the stone pops up turning fast and slows, the head drops in, the
	## grade lands with a thump in its color.
	_shown_at = Time.get_ticks_msec()
	_dim.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_dim, "modulate:a", 1.0, 0.18)
	fade.parallel().tween_property(_rays, "modulate:a", 0.9 if not bool(opts.get("low", false)) else 0.45, 0.6)
	var kind: String = str(opts.get("kind", "find"))
	DeepAudio.play("reveal", {"volume": 0.8})
	if kind in ["new", "best"]:
		DeepAudio.play("unlock", {"delay": 0.25, "volume": 0.85})
	if _stage != null:
		_stage.pivot_offset = _stage.custom_minimum_size * 0.5
		_stage.scale = Vector2.ONE * 0.35
		_stage.modulate.a = 0.0
		var pop := create_tween()
		pop.tween_property(_stage, "modulate:a", 1.0, 0.2)
		pop.parallel().tween_property(_stage, "scale", Vector2.ONE * 1.06, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(_stage, "scale", Vector2.ONE, 0.2)
		var spin := create_tween()
		spin.tween_method(func(v: float) -> void:
			if is_instance_valid(_view):
				_view.call("set_spin", v), 9.0, 0.6, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _head != null:
		_head.modulate.a = 0.0
		var drop := create_tween()
		drop.tween_interval(0.12)
		drop.tween_property(_head, "modulate:a", 1.0, 0.3)
	var land := create_tween()
	land.tween_interval(0.62)
	land.tween_callback(_land_stamp)
	get_tree().process_frame.connect(_place_rays, CONNECT_ONE_SHOT)

func _place_rays() -> void:
	if is_instance_valid(_stage) and _stage.is_inside_tree() and is_instance_valid(_rays):
		_rays.set("offset", _stage.global_position + _stage.size * 0.5 - _root.size * 0.5)
		var heart: Vector2 = _stage.global_position + _stage.size * 0.5
		var grand: bool = str(opts.get("kind", "")) in ["best", "new"] and not bool(opts.get("low", false))
		DeepUi.burst(_root, heart, _tone.lightened(0.3), 90 if grand else 50, 520.0 if grand else 360.0, 1.2, 8.0)
		DeepUi.burst(_root, heart, Color.WHITE, 30, 300.0, 0.9, 5.0)

func _land_stamp() -> void:
	if not is_instance_valid(_stamp):
		return
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.scale = Vector2.ONE * 2.3
	_stamp.rotation = -0.12
	_stamp.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_stamp, "rotation", -0.04, 0.24)
	var tier: String = str(DeepStone.grade(stone).tier)
	DeepAudio.play(DeepSoundBank.grade_sound(tier), {"volume": 0.95})
	if tier in ["EXQUISITE", "PEERLESS"] or DeepStone.is_opal(stone):
		DeepAudio.play("jackpot", {"delay": 0.18, "volume": 0.7})
	DeepAudio.rumble(0.3, 0.5, 0.12)
	if _stamp.is_inside_tree():
		DeepUi.shake(_stamp.get_parent() as Control, 5.0, 0.2)
		DeepUi.burst(_root, _stamp.global_position + _stamp.size * 0.5, _tone, 40, 260.0, 0.8, 6.0)

func _clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and actions.is_empty():
		_next()

func _next() -> void:
	## A click too soon after it came up (the one that brought it) does not count.
	if Time.get_ticks_msec() - _shown_at < 380:
		return
	_close("next")

func _choose(action: Dictionary) -> void:
	if _closing:
		return
	## Carried out first, so whoever is told the spotlight closed sees the stone's fate done.
	var call: Callable = action.get("call", Callable())
	if call.is_valid():
		call.call()
	_close("action")

func _close(how: String) -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.set_parallel(true)
	for child in _root.get_children():
		if child is CanvasItem:
			tween.tween_property(child, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(queue_free)
	if _open == self:
		_open = null
	done.emit(how)

func _input(event: InputEvent) -> void:
	if _closing or not is_instance_valid(_root):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if actions.is_empty():
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				_next()
			elif event.keycode == KEY_ESCAPE:
				_close("skip")
		else:
			if event.keycode == KEY_ESCAPE:
				for action in actions:
					if bool(action.get("dismiss", false)):
						_choose(action)
						break
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				for action in actions:
					if bool(action.get("main", false)) and not bool(action.get("risky", false)):
						_choose(action)
						break
		get_viewport().set_input_as_handled()
