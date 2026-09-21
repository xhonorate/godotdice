extends CanvasLayer
## The close look: right-click a stone, a die or a creature anywhere and it opens here,
## large and live, with everything there is to know about it laid out beside it. The same
## sheet, dressed with light and a title, is how a new stone is presented when one is won.
##
## One sheet at a time, above every screen. Escape, a right-click or a click outside closes
## it. The 3D view inside it is the only one it costs, and only while it is open.

const GemView = preload("res://view/gems/gem_view.gd")
const DiceView = preload("res://view/dice/dice_view.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const CreatureStage = preload("res://view/creatures/creature_stage.gd")

const FACE_TEXT: Dictionary = {
	"wild": "Wild: counts as any value for patterns, and as the die's top face for totals.",
	"gem": "Gem: every gem in your rail fires this turn, whatever the hand shows.",
	"exploding": "Exploding: rolls again and adds the result, up to three times.",
	"locked": "Locked: once it shows, the die cannot be rerolled for the rest of the fight.",
	"mirror": "Mirror: copies the highest other die in your hand.",
	"blank": "Blank: no value and no pattern at all."}
const TERM_WORDS: Dictionary = {"high": "its highest die", "low": "its lowest die", "total": "its total", "value": "the matched value",
	"second": "the second matched value", "count": "the number of matching dice", "max_total": "the most its dice could roll",
	"odd": "its odd dice", "even": "its even dice", "distinct": "its different values", "run_high": "the top of its run",
	"run_length": "the length of its run", "set_value": "its best set's value", "set_count": "the size of its best set",
	"depth": "the depth", "turn": "the turn number", "dice": "its number of dice", "block": "its block", "hp": "its health",
	"hp_missing": "its missing health", "missing": "how far its total falls short"}
const TARGET_WORDS: Dictionary = {"hero": "one of you", "heroes": "all of you", "self": "itself", "enemy": "the target",
	"enemies": "every creature", "allies": "its allies", "all": "everyone"}

static var _sheet: CanvasLayer = null

var _dim: ColorRect
var _panel: PanelContainer
var _stage: Control
var _details: VBoxContainer
var _title: Label
var _rays: Control
var _close: Button

# --- opening -------------------------------------------------------------------------------

static func is_open() -> bool:
	return _sheet != null and is_instance_valid(_sheet)

static func close() -> void:
	if is_open():
		_sheet.call("_dismiss")

static func _begin(tone: Color, fanfare: Dictionary = {}) -> CanvasLayer:
	if DisplayServer.get_name() == "headless":
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if is_open():
		_sheet.queue_free()
	_sheet = load("res://view/inspect/inspector.gd").new()
	## A fanfare brings its own sound with it; a plain close look only slides open.
	if fanfare.is_empty():
		DeepAudio.play("ui_open", {"volume": 0.6})
	tree.root.add_child(_sheet)
	_sheet.call("_frame", tone, fanfare)
	return _sheet

static func stone(item: Dictionary, opts: Dictionary = {}) -> void:
	var appraised: bool = bool(item.get("appraised", true))
	var tone: Color = DeepUi.tier_colour(str(DeepStone.grade(item).tier)) if appraised else DeepUi.colour(DeepStone.colour(item))
	var sheet := _begin(tone, opts.get("fanfare", {}))
	if sheet != null:
		sheet.call("_fill_stone", item, opts)

static func die(item: Dictionary, opts: Dictionary = {}) -> void:
	var sheet := _begin(DiceIcons.palette(str(item.get("key", "D6"))).body, opts.get("fanfare", {}))
	if sheet != null:
		sheet.call("_fill_die", item, opts)

static func creature(foe: Dictionary, battle: Dictionary = {}, opts: Dictionary = {}) -> void:
	var sheet := _begin(DeepUi.BAD if bool(foe.get("warden", false)) else Color("c8a8ff"))
	if sheet != null:
		sheet.call("_fill_creature", foe, battle, opts)

static func announce(title: String, text: String, glyph: String, tone: Color = DeepUi.ACCENT) -> void:
	## A big moment with no object: a new setting, a new mine.
	var sheet := _begin(tone, {"title": title, "subtitle": ""})
	if sheet != null:
		sheet.call("_fill_announcement", text, glyph, tone)

# --- the frame -----------------------------------------------------------------------------

func _frame(tone: Color, fanfare: Dictionary) -> void:
	layer = 60
	var root := Control.new()
	root.theme = DeepUi.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.01, 0.74)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_dismiss())
	root.add_child(_dim)
	if not fanfare.is_empty():
		_rays = Rays.new(tone)
		_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(_rays)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)
	var column := DeepUi.vbox(centre, 14)
	if not fanfare.is_empty():
		_title = DeepUi.title(column, str(fanfare.get("title", "")), 44, tone.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
		_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_title.add_theme_constant_override("outline_size", 10)
		if not str(fanfare.get("subtitle", "")).is_empty():
			DeepUi.label(column, str(fanfare.subtitle), 16, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_panel = PanelContainer.new()
	var style := DeepUi.raised(Color(0.045, 0.055, 0.08, 0.97), Color(tone, 0.75), 18, 20, 0.7)
	style.set_border_width_all(2)
	style.shadow_color = Color(tone, 0.25)
	style.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_dismiss())
	column.add_child(_panel)
	var row := DeepUi.hbox(_panel, 24)
	var left := DeepUi.vbox(row, 8)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(400, 460)
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(_stage)
	var halo := Halo.new(tone)
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(halo)
	DeepUi.label(left, "Drag to turn it", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_details = DeepUi.vbox(scroll, 12)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var foot := DeepUi.hbox(column, 12)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	if fanfare.is_empty():
		_close = DeepUi.icon_button(foot, "cross_out", "Close", _dismiss, 15, DeepUi.MUTED)
		DeepUi.label(foot, "Esc, right-click or click outside to close", 12, DeepUi.DIM)
	else:
		_close = DeepUi.primary(foot, "check", str(fanfare.get("button", "Wonderful")), _dismiss, 18, tone)
		_close.custom_minimum_size.x = 240
	## In: the sheet rises and settles; a won thing arrives in a burst of its own light.
	_dim.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_dim, "modulate:a", 1.0, 0.18)
	DeepUi.pop_in(column, 0.0, 0.88, 0.34)
	if not fanfare.is_empty():
		var burst := create_tween()
		burst.tween_interval(0.12)
		burst.tween_callback(func() -> void:
			DeepUi.burst(root, root.get_viewport_rect().size * 0.5 - Vector2(250, 40), tone.lightened(0.3), 90, 520.0, 1.3, 9.0)
			DeepUi.burst(root, root.get_viewport_rect().size * 0.5 - Vector2(250, 40), Color.WHITE, 40, 300.0, 1.0, 6.0)
			if _title != null:
				DeepUi.pulse(_title, 1.25, 0.5))

func _dismiss() -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	DeepAudio.play("ui_close", {"volume": 0.6})
	var tween := create_tween()
	tween.set_parallel(true)
	for child in get_children():
		if child is CanvasItem:
			tween.tween_property(child, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(queue_free)
	if _sheet == self:
		_sheet = null

func _input(event: InputEvent) -> void:
	## While the sheet is up, the keyboard belongs to it.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_dismiss()
		get_viewport().set_input_as_handled()

func _section(glyph: String, text: String, tone: Color = DeepUi.ACCENT) -> VBoxContainer:
	var box := DeepUi.vbox(_details, 6)
	DeepUi.section(box, glyph, text, tone, 13)
	return box

# --- stones ------------------------------------------------------------------------------------

func _fill_stone(item: Dictionary, opts: Dictionary) -> void:
	var view := GemView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	view.set_slot(220.0)
	view.set_drift(true)
	view.set_spin(0.35)
	view.configure(item)
	view.enable_interaction()
	_stage.add_child(view)
	var appraised: bool = bool(item.get("appraised", true))
	var grade: Dictionary = DeepStone.grade(item)
	var tier: Color = DeepUi.tier_colour(str(grade.tier))
	var colour_key: String = DeepStone.colour(item)
	var head := DeepUi.vbox(_details, 6)
	if not appraised:
		DeepUi.title(head, DeepStone.raw_name(item), 28, DeepUi.PAPER)
		DeepUi.wrap(head, "Unappraised. Its size and colour are there for anyone to see; its skill, its cut and what is frozen inside it are not. Put it under a loupe at a landing, or at home on the Appraise tab.", 14, DeepUi.MUTED)
		var facts := DeepUi.hbox(head, 10)
		DeepUi.pill(facts, "carat", "%d carats" % int(item.get("carat", 1)), DeepUi.PAPER, 14)
		DeepUi.pill(facts, "gem", "%s: %s" % [str(DeepContent.colour(colour_key).get("name", colour_key)), str(DeepContent.colour(colour_key).get("domain", ""))], DeepUi.colour(colour_key), 14)
		var slots: int = DeepStone.inclusion_slots(int(item.get("clarity", 3)))
		if slots > 0:
			DeepUi.pill(facts, "spark", DeepUi.plural(slots, "inclusion") + " inside", DeepUi.INFO, 14)
		if bool(item.get("inclusions_revealed", false)):
			_inclusions(item)
		return
	DeepUi.title(head, DeepStone.name(item), 28, tier)
	var tags := DeepUi.hbox(head, 8)
	DeepUi.pill(tags, "star", "%s · grade %d of 100" % [str(grade.name), int(grade.score)], tier, 13)
	DeepUi.pill(tags, "coin", "worth %d gold" % DeepStone.value(item), DeepUi.ACCENT, 13)
	var skill: Dictionary = DeepStone.skill_of(item)
	## What it does.
	var does := _section(GemIcons.emblem(str(item.get("skill", ""))), "What it does")
	var skill_row := DeepUi.hbox(does, 8)
	DeepUi.title(skill_row, str(skill.get("name", "")), 20, DeepUi.PAPER)
	DeepUi.chip(skill_row, str(skill.get("rarity", "COMMON")).capitalize(), DeepUi.MUTED, 11)
	DeepUi.chip(skill_row, "%s · %s" % [str(DeepContent.colour(colour_key).get("name", colour_key)), str(DeepContent.colour(colour_key).get("domain", ""))], DeepUi.colour(colour_key), 11)
	DeepUi.wrap(does, str(skill.get("text", "")), 15, DeepUi.PAPER)
	var effective: Dictionary = DeepStone.effective(item, opts.get("context", {}))
	DeepUi.stat(does, "carat", "Every amount it deals is multiplied by %.2f." % float(effective.magnitude), DeepUi.ACCENT, 13)
	if skill.get("flawless", null) is Dictionary:
		var lit: bool = DeepStone.is_flawless(item)
		DeepUi.stat(does, "star", ("Flawless: " if lit else "If it were Flawless: ") + str(skill.flawless.get("text", "")), DeepUi.tier_colour("PEERLESS") if lit else DeepUi.DIM, 13)
	## When it fires: the whole ladder, with the rung this stone stands on.
	var fires := _section("cut", "When it fires")
	var trigger: Dictionary = skill.get("trigger", {"kind": "always"})
	var step: int = int(effective.cut_step)
	for rung in range(5):
		var described: Dictionary = DeepPatterns.describe(trigger, rung)
		var here: bool = rung == mini(step, 4)
		var line := DeepUi.panel(fires, Color(DeepUi.ACCENT, 0.12) if here else Color(0, 0, 0, 0), Color(DeepUi.ACCENT, 0.6) if here else Color(0, 0, 0, 0), 6, 4)
		var cells := DeepUi.hbox(line, 10)
		var name_label := DeepUi.label(cells, DeepContent.cut_name(rung), 13, DeepUi.ACCENT_HI if here else DeepUi.DIM)
		name_label.custom_minimum_size.x = 64
		DiceIcons.build(cells, described, 18, DeepUi.PAPER if here else DeepUi.MUTED)
		DeepUi.wrap(cells, str(described.words), 12, DeepUi.PAPER if here else DeepUi.DIM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if step > int(item.get("cut", 0)):
		DeepUi.stat(fires, "spark", "Its clarity lifts it %s above its cut." % DeepUi.plural(step - int(item.get("cut", 0)), "rung"), DeepUi.INFO, 12)
	## The four C's.
	var cs := _section("gem", "Its four C's")
	_c_row(cs, "carat", "Carat", "%d" % int(item.get("carat", 1)), float(int(item.get("carat", 1))) / float(DeepStone.carat_max()), "How much. One multiplier over everything it does; %d is the most a stone can weigh." % DeepStone.carat_max())
	_c_row(cs, "cut", "Cut", DeepContent.cut_name(int(item.get("cut", 0))), float(int(item.get("cut", 0)) + 1) / 5.0, "How often. A better cut stands on a looser rung of its trigger ladder.")
	var clarity: int = int(item.get("clarity", 3))
	_c_row(cs, "clarity", "Clarity", DeepContent.clarity_name(clarity), float(clarity + 1) / 6.0, _clarity_words(clarity))
	_inclusions(item)
	var where: Dictionary = item.get("provenance", {})
	if not where.is_empty():
		var found := _section("map", "Found")
		var parts: Array = []
		if not str(where.get("mine", "")).is_empty():
			parts.append(str(DeepContent.mine(str(where.mine)).get("name", where.mine)))
		if where.has("depth"):
			parts.append("depth %d" % int(where.depth))
		if where.has("source"):
			parts.append("from %s" % str(where.source).replace("_", " "))
		if where.has("date"):
			parts.append(str(where.date))
		DeepUi.label(found, ", ".join(parts) if not parts.is_empty() else "Nobody remembers where.", 13, DeepUi.MUTED)

func _clarity_words(clarity: int) -> String:
	match clarity:
		5: return "Flawless: judged a Cut step better, hits half as hard again, and has its Flawless line."
		4: return "Pristine: judged a Cut step better."
		3: return "Clear: an honest stone with nothing frozen inside."
	return "%s: carries %s, the quirks that make one stone unlike another." % [DeepContent.clarity_name(clarity), DeepUi.plural(DeepStone.inclusion_slots(clarity), "inclusion")]

func _c_row(parent: Node, glyph: String, name: String, value: String, share: float, words: String) -> void:
	var row := DeepUi.hbox(parent, 10)
	DeepUi.icon(row, glyph, 20, DeepUi.ACCENT, GemIcons.hint(glyph))
	var label := DeepUi.label(row, name, 14, DeepUi.MUTED)
	label.custom_minimum_size.x = 60
	var shown := DeepUi.title(row, value, 16, DeepUi.PAPER)
	shown.custom_minimum_size.x = 90
	var meter := DeepUi.bar(row, 8.0, DeepUi.ACCENT, Color(DeepUi.LINE, 0.7))
	meter.custom_minimum_size = Vector2(120, 8)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.set_values(clampf(share, 0.0, 1.0))
	DeepUi.wrap(parent, words, 12, DeepUi.DIM)

func _inclusions(item: Dictionary) -> void:
	if item.get("inclusions", []).is_empty():
		return
	var box := _section("spark", "Frozen inside", DeepUi.INFO)
	for key in item.inclusions:
		var inclusion: Dictionary = DeepContent.inclusion(str(key))
		var cls: String = str(inclusion.get("class", "PINPOINT"))
		var tone: Color = StoneCard.INCLUSION_TONES.get(cls, DeepUi.INFO)
		var row := DeepUi.hbox(box, 10)
		DeepUi.pill(row, str(StoneCard.INCLUSION_GLYPHS.get(cls, "spark")), str(inclusion.get("name", key)), tone, 13).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var words := DeepUi.vbox(row, 1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.wrap(words, str(inclusion.get("text", "")), 13, DeepUi.PAPER)
		DeepUi.label(words, "%s · %s" % [cls.capitalize(), str(inclusion.get("rarity", "COMMON")).capitalize()], 11, DeepUi.DIM)

# --- dice --------------------------------------------------------------------------------------

func _fill_die(item: Dictionary, opts: Dictionary) -> void:
	var roll: Dictionary = opts.get("roll", {})
	var view := DiceView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 70)
	view.enable_interaction()
	_stage.add_child(view)
	view.configure(item, roll, false, false, DeepUi.ACCENT)
	var faces: Array = item.get("faces", [])
	var palette: Dictionary = DiceIcons.palette(str(item.get("key", "D6")))
	var head := DeepUi.vbox(_details, 6)
	DeepUi.title(head, DeepDice.describe(item), 28, palette.body.lightened(0.2))
	var tags := DeepUi.hbox(head, 8)
	var definition: Dictionary = DeepContent.die(str(item.get("key", "")))
	DeepUi.pill(tags, "die", str(item.get("shape", definition.get("shape", "D6"))), palette.body, 13)
	if definition.has("rarity"):
		DeepUi.pill(tags, "star", str(definition.rarity).capitalize(), DeepUi.MUTED, 13)
	if not roll.is_empty():
		var shown: String = DiceIcons.face_text(int(roll.get("value", 0)), str(roll.get("kind", "plain")))
		DeepUi.pill(tags, "check", "showing %s" % shown, DeepUi.ACCENT, 13)
		if bool(roll.get("locked", false)):
			DeepUi.pill(tags, "lock_open", "locked in place", DeepUi.BAD, 13)
		elif int(roll.get("rerolls", 0)) > 0:
			DeepUi.pill(tags, "reroll", "rerolled %s" % DeepUi.plural(int(roll.rerolls), "time"), DeepUi.INFO, 13)
	## Its faces, each one clickable to turn the die to it.
	var face_box := _section("die", "Its faces")
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	face_box.add_child(grid)
	var values: Array = []
	var kinds: Dictionary = {}
	for index in range(faces.size()):
		var face: Variant = faces[index]
		var value: int = int(face.get("value", index + 1)) if face is Dictionary else int(face)
		var kind: String = str(face.get("kind", "plain")) if face is Dictionary else "plain"
		values.append(value)
		if kind != "plain":
			kinds[kind] = true
		var chip := Button.new()
		chip.flat = true
		chip.custom_minimum_size = Vector2(52, 58)
		chip.tooltip_text = FACE_TEXT.get(kind, "An ordinary face: %d." % value)
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var here: bool = not roll.is_empty() and int(roll.get("face", -1)) == index
		var tone: Color = palette.body if kind == "plain" else DiceIcons.face_kind_tint(kind)
		var drawn := DiceIcons.face(40, value, tone, str(item.get("shape", "D6")), here, DiceIcons.face_text(value, kind))
		drawn.position = Vector2(6, 4)
		chip.add_child(drawn)
		var face_index: int = index
		chip.pressed.connect(func() -> void: view.focus_face(face_index))
		DeepUi.juice(chip, 1.12)
		grid.add_child(chip)
	for kind in kinds:
		DeepUi.stat(face_box, "spark", str(FACE_TEXT.get(kind, kind)), DiceIcons.face_kind_tint(str(kind)).lightened(0.2), 13)
	## What it tends to roll.
	var stats := _section("hourglass", "What it rolls")
	var total: float = 0.0
	var odd: int = 0
	var distinct: Dictionary = {}
	for value in values:
		total += float(value)
		distinct[value] = true
		if int(value) % 2 == 1:
			odd += 1
	var average: float = total / float(maxi(1, values.size()))
	var facts := DeepUi.hbox(stats, 10)
	DeepUi.pill(facts, "sum", "average %.1f" % average, DeepUi.PAPER, 13)
	DeepUi.pill(facts, "peak", "%d to %d" % [int(values.min()) if not values.is_empty() else 0, int(values.max()) if not values.is_empty() else 0], DeepUi.PAPER, 13)
	DeepUi.pill(facts, "odd", "%d odd, %d even" % [odd, values.size() - odd], DeepUi.PAPER, 13)
	DeepUi.wrap(stats, _die_character(values, distinct.size()), 13, DeepUi.MUTED)
	var engraving: String = str(item.get("engraving", ""))
	if not engraving.is_empty():
		var carved := _section("pick", "Engraved", DeepUi.ACCENT)
		for key in DeepContent.section("engravings"):
			var entry: Dictionary = DeepContent.section("engravings")[key]
			if str(entry.get("key", "")).to_lower() == engraving.to_lower() or str(key).to_lower() == engraving.to_lower():
				DeepUi.title(carved, str(entry.get("name", engraving)), 18, DeepUi.ACCENT_HI)
				DeepUi.wrap(carved, str(entry.get("text", "")), 14, DeepUi.PAPER)

func _die_character(values: Array, distinct: int) -> String:
	## A line on what the die is good for, read off its faces.
	if values.size() <= 4:
		return "Few faces: it repeats itself, which makes pairs and sets."
	if distinct < values.size():
		return "Repeated faces: it leans toward the values it carries twice, which makes pairs."
	if values.size() >= 12:
		return "Many faces: big totals and high dice, but it rarely matches anything."
	return "Evenly spread: a fair die."

# --- creatures ---------------------------------------------------------------------------------

func _fill_creature(foe: Dictionary, battle: Dictionary, opts: Dictionary) -> void:
	var key: String = str(foe.get("key", ""))
	var definition: Dictionary = DeepContent.creature(key)
	var stage := CreatureStage.new(key, bool(foe.get("warden", false)))
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(stage)
	var warden: bool = bool(foe.get("warden", false))
	var head := DeepUi.vbox(_details, 6)
	var title_row := DeepUi.hbox(head, 10)
	DeepUi.title(title_row, str(foe.get("name", definition.get("name", key))), 28, Color("ffb0a0") if warden else DeepUi.PAPER)
	if warden:
		DeepUi.pill(title_row, "crown", "Warden", DeepUi.BAD, 13).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.wrap(head, str(definition.get("text", "")), 14, DeepUi.MUTED)
	if foe.has("hp"):
		var life := DeepUi.hbox(head, 8)
		DeepUi.icon(life, "heart", 18, DeepUi.BAD)
		var bar := DeepUi.bar(life, 16.0, DeepUi.BAD, DeepUi.HP_LOST)
		bar.custom_minimum_size = Vector2(240, 16)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.set_values(float(foe.hp) / float(maxi(1, int(foe.get("max_hp", 1)))), "%d / %d" % [int(foe.hp), int(foe.get("max_hp", 1))])
		var effects: Array = EffectChips.for_enemy(foe, battle)
		if not effects.is_empty():
			var chips := EffectChips.Row.new(18)
			head.add_child(chips)
			chips.show_effects(effects)
			var notes := DeepUi.vbox(head, 3)
			for effect in effects:
				DeepUi.stat(notes, str(effect.glyph), "%s: %s" % [str(effect.title), str(effect.text)], Color(effect.tone).lightened(0.2), 12)
	## What it means to do this turn.
	if not foe.get("intents", []).is_empty():
		var now := _section("sword", "This turn", DeepUi.BAD)
		var dice := DeepUi.hbox(now, 4)
		DeepUi.label(dice, "It rolled", 13, DeepUi.MUTED)
		for roll in foe.get("hand", []):
			dice.add_child(DiceIcons.face(26, int(roll.value), DiceIcons.palette(str(roll.get("key", "D6"))).body, str(roll.get("shape", "D6")), true))
		for intent in foe.intents:
			var line := DeepUi.hbox(now, 8)
			DeepUi.icon(line, GemIcons.emblem(str(intent.move).to_upper()), 22, DeepUi.BAD)
			DeepUi.title(line, str(intent.move), 17, DeepUi.PAPER)
			var parts: Array = []
			for effect in intent.get("effects", []):
				parts.append(_resolved_words(effect))
			var victim: Dictionary = DeepBattle.player(battle, str(intent.get("target", "")))
			if not victim.is_empty():
				parts.append("aimed at %s" % str(victim.get("name", "")))
			DeepUi.wrap(line, ", ".join(parts), 13, DeepUi.PAPER).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Everything it can do.
	var moves := _section("book", "Its moves")
	var highlight: String = str(opts.get("move", ""))
	for move in definition.get("moves", []):
		_move_row(moves, move, str(move.get("name", "")) == highlight)
	for phase in definition.get("phases", []):
		DeepUi.stat(moves, "crown", "Below %d%% health it fights with:" % int(phase.get("below_hp_pct", 0)), DeepUi.BAD, 13)
		for move in phase.get("moves", []):
			_move_row(moves, move, str(move.get("name", "")) == highlight)
	var rolls := _section("die", "Its dice")
	var dice_row := DeepUi.hbox(rolls, 6)
	for die_key in definition.get("dice", []):
		DeepUi.pill(dice_row, "die", str(die_key), DiceIcons.palette(str(die_key)).body, 12)
	DeepUi.label(rolls, "Policy: %s" % str(definition.get("policy", "best")).replace("_", " "), 12, DeepUi.DIM)

func _move_row(parent: Node, move: Dictionary, highlight: bool) -> void:
	var panel := DeepUi.panel(parent, Color(DeepUi.BAD, 0.12) if highlight else Color(1, 1, 1, 0.03), Color(DeepUi.BAD, 0.6) if highlight else Color(0, 0, 0, 0), 8, 8)
	var box := DeepUi.vbox(panel, 4)
	var head := DeepUi.hbox(box, 10)
	DeepUi.icon(head, GemIcons.emblem(str(move.get("name", "")).to_upper()), 20, DeepUi.BAD if highlight else DeepUi.MUTED)
	DeepUi.title(head, str(move.get("name", "")), 16, DeepUi.PAPER)
	var trigger: Dictionary = move.get("trigger", {"kind": "always"})
	var described: Dictionary = DeepPatterns.describe(trigger, 0)
	DiceIcons.build(head, described, 16, DeepUi.MUTED)
	var when: String = "Its every turn." if str(trigger.get("kind", "always")) == "always" else "When its dice show: " + str(described.words).trim_suffix(".").to_lower() + "."
	DeepUi.label(box, when, 12, DeepUi.DIM)
	for effect in move.get("effects", []):
		DeepUi.stat(box, _effect_glyph(str(effect.get("kind", ""))), _effect_words(effect), DeepUi.PAPER, 13)

func _effect_glyph(kind: String) -> String:
	return str({"damage": "sword", "block": "shield", "poison": "drop", "stun": "stun", "remove_block": "split_shield", "die_steal": "die",
		"heal": "heart", "curse": "eye"}.get(kind, "spark"))

func _effect_words(effect: Dictionary) -> String:
	var kind: String = str(effect.get("kind", ""))
	var amount: String = _amount_words(effect.get("amount", 0))
	var target: String = str(TARGET_WORDS.get(str(effect.get("target", "hero")), str(effect.get("target", ""))))
	var repeat: int = int(effect.get("repeat", 1))
	var words: String
	match kind:
		"damage": words = "Deals %s damage to %s" % [amount, target]
		"block": words = "Gains %s block" % amount
		"poison": words = "Poisons %s for %s" % [target, amount]
		"stun": words = "Stuns %s" % target
		"remove_block": words = "Strips %s block from %s" % [amount, target]
		"die_steal": words = "Takes %s of %s's dice for a turn" % [amount, target]
		"heal": words = "Heals %s" % amount
		_: words = "%s %s" % [kind.replace("_", " ").capitalize(), amount]
	return words + (" (%d times)" % repeat if repeat > 1 else "") + "."

func _amount_words(expr: Variant) -> String:
	if expr is int or expr is float:
		return str(int(expr))
	if not expr is Dictionary:
		return "some"
	if expr.has("const"):
		return str(int(expr.const))
	if expr.has("term"):
		return str(TERM_WORDS.get(str(expr.term), str(expr.term).replace("_", " ")))
	var args: Array = []
	for argument in expr.get("args", []):
		args.append(_amount_words(argument))
	match str(expr.get("op", "+")):
		"+": return " plus ".join(args)
		"-": return " minus ".join(args)
		"*": return " × ".join(args)
		"min": return "the smaller of " + " and ".join(args)
		"max": return "the larger of " + " and ".join(args)
		"floor_div": return " divided by ".join(args)
		"pct": return "%s%% of %s" % [args[1] if args.size() > 1 else "100", args[0] if not args.is_empty() else ""]
	return "some"

func _resolved_words(effect: Dictionary) -> String:
	var kind: String = str(effect.get("kind", ""))
	var amount: int = int(effect.get("amount", 0)) * maxi(1, int(effect.get("repeat", 1)))
	match kind:
		"damage": return "%d damage" % amount
		"block": return "+%d block for itself" % amount
		"poison": return "%d poison" % amount
		"stun": return "a stun"
		"remove_block": return "strips %d block" % amount
		"die_steal": return "takes a die"
		"heal": return "heals %d" % amount
	return kind.replace("_", " ")

# --- announcements -----------------------------------------------------------------------------

func _fill_announcement(text: String, glyph: String, tone: Color) -> void:
	var mark := DeepUi.center(_stage)
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DeepUi.icon(mark, glyph, 180, tone.lightened(0.25))
	DeepUi.wrap(_details, text, 18, DeepUi.PAPER).custom_minimum_size.x = 520

# --- light -------------------------------------------------------------------------------------

class Halo extends Control:
	## The pool of light the inspected thing stands in.
	var tone: Color
	var _clock: float = 0.0
	func _init(colour: Color) -> void:
		tone = colour
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		var centre := size * 0.5
		var pulse: float = 1.0 + 0.05 * sin(_clock * 1.8)
		var reach := size * 1.05 * pulse
		draw_texture_rect(glow, Rect2(centre - reach * 0.5, reach), false, Color(tone, 0.28))
		var floor_glow := Vector2(size.x * 0.8, size.y * 0.18)
		draw_texture_rect(glow, Rect2(Vector2(centre.x, size.y * 0.86) - floor_glow * 0.5, floor_glow), false, Color(tone, 0.4))
		for i in range(10):
			var t: float = fmod(_clock * 0.18 + float(i) / 10.0, 1.0)
			var x: float = centre.x + sin(float(i) * 2.1 + _clock * 0.4) * size.x * 0.3 * t
			draw_circle(Vector2(x, size.y * 0.86 - t * size.y * 0.8), 1.8, Color(tone.lightened(0.5), 0.8 * (1.0 - t)))

class Rays extends Control:
	## God rays wheeling behind a won thing.
	var tone: Color
	var _clock: float = 0.0
	func _init(colour: Color) -> void:
		tone = colour
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var centre := size * 0.5 + Vector2(-250, -20)
		var reach: float = size.length()
		var count := 14
		for i in range(count):
			var angle: float = _clock * 0.12 + TAU * float(i) / float(count)
			var width: float = 0.08 + 0.03 * sin(_clock * 1.3 + float(i))
			var a := centre + Vector2.from_angle(angle - width) * reach
			var b := centre + Vector2.from_angle(angle + width) * reach
			draw_colored_polygon(PackedVector2Array([centre, a, b]), Color(tone, 0.06))
		var glow: Texture2D = DeepUi.glow_texture()
		var core := Vector2(700, 700) * (1.0 + 0.06 * sin(_clock * 2.0))
		draw_texture_rect(glow, Rect2(centre - core * 0.5, core), false, Color(tone, 0.25))
