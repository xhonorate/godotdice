extends CanvasLayer
## The close look: right-click a stone, a die or a creature anywhere and it opens here,
## large and live, with everything there is to know about it laid out beside it. The same
## sheet, dressed with light and a title, is how a new stone is presented when one is won.
##
## One sheet at a time, above every screen. Escape, a right-click or a click outside closes
## it. The 3D view inside it is the only one it costs, and only while it is open.
##
## The sheet never scrolls. Its name and tags stay at the top; what is said about the thing
## is split into pages (a stone's skill and its four C's; a creature's turn and its moves),
## turned by the tabs under the name or by the arrow keys.

const GemView = preload("res://view/gems/gem_view.gd")
const DiceView = preload("res://view/dice/dice_view.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const CreatureStage = preload("res://view/creatures/creature_stage.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")

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
var _stage_hint: Label
## The name and tags, above the pages.
var _head: VBoxContainer
var _tabs: HBoxContainer
var _book: VBoxContainer
## The page being written to.
var _details: VBoxContainer
## Every page: {name, glyph, box}.
var _pages: Array = []
var _title: Label
var _rays: Control
var _close: Button
## The grade pill's popup: how its score is worked out, animated in over the ordinary page.
var _reveal: Control
## Every tween the popup's timeline is running, so a second click or a close can kill them
## before a late callback reaches into a row `_open_reveal` has already freed.
var _reveal_tweens: Array = []

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
	if DeepStone.is_birthstone(item):
		var own := _begin(GemMesh.tint(item), opts.get("fanfare", {}))
		if own != null:
			own.call("_fill_birthstone", item)
		return
	var appraised: bool = bool(item.get("appraised", true))
	var tone: Color = DeepUi.tier_color(str(DeepStone.grade(item).tier)) if appraised else DeepUi.color(DeepStone.color(item))
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

static func lapidary(character_key: String) -> void:
	## Someone new comes to the workshop: their plate and their Birthstone turning beside it,
	## and everything about them read out a line at a time rather than all at once.
	var character: Dictionary = DeepContent.character(character_key)
	if character.is_empty():
		return
	var stone: Dictionary = DeepStone.birthstone(character_key)
	var tone: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var sheet := _begin(tone, {"title": "A new lapidary", "subtitle": DeepContent.character_title(character_key), "button": "Take them on"})
	if sheet != null:
		sheet.call("_fill_lapidary", character_key, tone)

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
	_stage_hint = DeepUi.label(left, "Drag to turn it", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var right := DeepUi.vbox(row, 12)
	right.custom_minimum_size = Vector2(600, 560)
	_head = DeepUi.vbox(right, 6)
	_tabs = DeepUi.hbox(right, 6)
	_tabs.visible = false
	_book = DeepUi.vbox(right, 0)
	_book.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	## While the sheet is up, the keyboard belongs to it: the arrows turn its pages.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if _reveal != null and _reveal.visible:
				_close_reveal()
			else:
				_dismiss()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_TAB]:
			_step(-1 if event.keycode == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()

# --- pages -------------------------------------------------------------------------------------

func _page(name: String, glyph: String) -> VBoxContainer:
	## Begin a page: everything written to `_details` after this goes on it. The first page
	## is shown; with more than one, a tab for each turns between them.
	var box := DeepUi.vbox(_book, 12)
	box.visible = _pages.is_empty()
	_pages.append({"name": name, "glyph": glyph, "box": box})
	_details = box
	_draw_tabs()
	return box

func page_names() -> Array:
	var names: Array = _pages.map(func(page: Dictionary) -> String: return str(page.name))
	return names if not names.is_empty() else [""]

func show_page(name: String) -> void:
	for page in _pages:
		page.box.visible = str(page.name) == name
	_draw_tabs()

func _step(delta: int) -> void:
	if _pages.size() < 2:
		return
	var at: int = _pages.find_custom(func(page: Dictionary) -> bool: return page.box.visible)
	DeepAudio.play("ui_tab", {"volume": 0.6})
	show_page(str(_pages[posmod(at + delta, _pages.size())].name))

func _draw_tabs() -> void:
	DeepUi.clear(_tabs)
	_tabs.visible = _pages.size() > 1
	if not _tabs.visible:
		return
	for page in _pages:
		var name: String = str(page.name)
		DeepUi.tab_button(_tabs, str(page.glyph), name, page.box.visible, func() -> void: show_page(name), 13)

func _section(glyph: String, text: String, tone: Color = DeepUi.ACCENT) -> VBoxContainer:
	var box := DeepUi.vbox(_details, 6)
	DeepUi.section(box, glyph, text, tone, 13)
	return box

# --- stones ------------------------------------------------------------------------------------

func _fill_stone(item: Dictionary, opts: Dictionary) -> void:
	var reference: bool = bool(opts.get("reference", false))
	if reference:
		_stage_hint.hide()
		var frame := DeepUi.center(_stage)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		DeepUi.icon(frame, GemIcons.emblem(str(item.get("skill", ""))), 160, Color(DeepUi.color(DeepStone.color(item)), 0.65))
	else:
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
	var tier: Color = DeepUi.tier_color(str(grade.tier))
	var color_key: String = DeepStone.color(item)
	var head := _head
	if not appraised:
		DeepUi.title(head, DeepStone.raw_name(item), 28, DeepUi.PAPER)
		DeepUi.wrap(head, "Unappraised, and still half in its rock. Its color shows, and roughly how big it is; its skill, its exact weight, its cut and whatever is frozen inside it do not. A merchant will appraise it for pyrite, a landing will do one for free, or it can wait for the Appraise tab at home.", 14, DeepUi.MUTED)
		var facts := DeepUi.hbox(head, 10)
		var named: Dictionary = DeepStone.size_class(int(item.get("carat", 1)))
		DeepUi.pill(facts, "carat", "%s: %s" % [str(named.name), str(named.range)], DeepUi.PAPER, 14)
		DeepUi.pill(facts, "gem", "%s: %s" % [str(DeepContent.color(color_key).get("name", color_key)), str(DeepContent.color(color_key).get("domain", ""))], DeepUi.color(color_key), 14, "", DeepUi.is_rainbow(color_key))
		if bool(item.get("inclusions_revealed", false)) and not item.get("inclusions", []).is_empty():
			var _page_container = _page("Inclusions", "spark")
			_inclusions(item, _page_container)
		return
	## A reference is a skill, not a stone: nobody owns it, so its grade and its worth are
	## numbers about a thing that does not exist and are left off the page entirely.
	var skill: Dictionary = DeepStone.skill_of(item)
	DeepUi.title(head, str(skill.get("name", item.get("skill", ""))) if reference else DeepStone.name(item), 28,
		DeepUi.color(color_key).lightened(0.25) if reference else tier)
	var tags := DeepUi.hbox(head, 8)
	var rarity: String = str(skill.get("rarity", "COMMON"))
	if not reference:
		var grade_pill := DeepUi.pill(tags, "star", "%s · grade %d of 100" % [str(grade.name), int(grade.score)], tier, 13, "Click to see how this grade is worked out")
		grade_pill.mouse_filter = Control.MOUSE_FILTER_STOP
		grade_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DeepUi.juice(grade_pill, 1.06)
		grade_pill.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_reveal(item))
	DeepUi.pill(tags, "spark", rarity.capitalize(), StoneCard._rarity_color(rarity), 13, "", StoneCard.is_mythic(rarity))
	if reference:
		DeepUi.pill(tags, "eye", "Seen, not kept", DeepUi.MUTED, 13, "One of these has passed through your hands. The vault keeps the page, not the stone.")
	elif DeepStone.is_fragile(item):
		DeepUi.pill(tags, "split_shield", "Fragile · cannot sell or keep", DeepUi.BAD, 13)
	else:
		DeepUi.pill(tags, "coin", "Value · %d gold" % DeepStone.value(item), DeepUi.ACCENT, 13)
	## Everything below the tags is one page: what it does, when it fires, its purity.
	_page("", "")
	var does := _section(GemIcons.emblem(str(item.get("skill", ""))), "What it does")
	var skill_row := DeepUi.hbox(does, 8)
	DeepUi.title(skill_row, str(skill.get("name", "")), 20, DeepUi.PAPER)
	var effective: Dictionary = DeepStone.effective(item, opts.get("context", {}))
	if int(effective.carat) != int(item.carat) or int(effective.cut_step) != int(item.cut) or int(effective.clarity) != int(item.clarity):
		DeepUi.wrap(does, "Effective: %d ct · %s Cut · %s Clarity" % [int(effective.carat), DeepContent.cut_name(int(effective.cut_step)), DeepContent.clarity_name(int(effective.clarity))], 12, DeepUi.INFO)
	var mods: Array = DeepStone.modifiers(item)
	_effect_line(does, item, mods, opts.get("context", {}))
	StoneCard.carat_lines(does, item, opts.get("context", {}), 13)
	if reference:
		DeepUi.stat(does, "eye", "Written as it comes out of the rock at its plainest: one carat, a Poor cut, nothing inside. The one you find will be its own.", DeepUi.DIM, 12)
	var carat_mult_mods: Array = mods.filter(func(m: Dictionary) -> bool: return str(m.get("kind", "")) == "carat_mult")
	if not carat_mult_mods.is_empty():
		var cm: Dictionary = carat_mult_mods[0]
		var counted: int = int(round(float(int(item.get("carat", 1))) * float(cm.get("amount", 1.0))))
		_inclusion_note(does, cm, "makes its carats count as %d for what weight buys." % counted)
	if bool(effective.flawless) and skill.get("flawless", null) is Dictionary:
		var flawless := DeepUi.hbox(does, 6)
		DeepUi.icon(flawless, "star", 14, DeepUi.tier_color("PEERLESS"))
		DeepUi.effect_text(flawless, "Flawless: " + DeepStone.flawless_text(item, opts.get("context", {})), 13, DeepUi.tier_color("PEERLESS"))
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
		DeepUi.stat(fires, "spark", "It is judged %s above its cut." % DeepUi.plural(step - int(item.get("cut", 0)), "rung"), DeepUi.INFO, 12)
	var cut_override_mods: Array = mods.filter(func(m: Dictionary) -> bool: return str(m.get("kind", "")) == "cut_override")
	if not cut_override_mods.is_empty():
		var om: Dictionary = cut_override_mods[0]
		_inclusion_note(fires, om, "makes its cut count as %s." % DeepContent.cut_name(int(om.get("value", 0))))
	## Purity, and whatever is frozen inside it: the rest of the page. Its exact carat and
	## cut, and how they weigh into the grade, live in the grade pill's own popup instead.
	var clarity: int = int(item.get("clarity", 3))
	var purity := _section("clarity", "Clarity")
	var prow := DeepUi.hbox(purity, 10)
	DeepUi.title(prow, DeepContent.clarity_name(clarity), 18, DeepUi.PAPER)
	DeepUi.wrap(prow, _clarity_words(clarity), 13, DeepUi.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inclusions(item, purity)

func _effect_line(parent: Node, item: Dictionary, mods: Array, context: Dictionary = {}) -> void:
	## The effect is the reason a player opens this sheet, so it leads in bold, with the carat
	## multiplier folded into the same paragraph instead of a line of its own. Anything an
	## inclusion adds on top of the plain carat curve rides right after it, in that
	## inclusion's own color and mark, so the reader sees where the extra strength comes from.
	##
	## A skill whose every effect is a whole number has no multiplier to show: weight buys it
	## more goes instead, and `carat_lines` says so underneath in words. Writing "x3.4" beside
	## a Cascade would be a number that multiplies nothing.
	var scales: bool = DeepStone.magnitude_matters(item)
	var carat: int = int(item.get("carat", 1))
	var carat_mult: float = 1.0
	for m in mods:
		if str(m.get("kind", "")) == "carat_mult":
			carat_mult *= float(m.get("amount", 1.0))
	var base_mult: float = DeepStone.carat_multiplier(float(carat) * carat_mult)
	var rtl := RichTextLabel.new()
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.push_font(DeepUi.bold_font())
	rtl.push_font_size(17)
	rtl.push_color(DeepUi.PAPER)
	DeepUi.push_effect_text(rtl, DeepStone.text(item, context))
	rtl.pop_all()
	if scales and base_mult != 1.0:
		rtl.add_text("  ")
		rtl.push_hint("Bonus from %d carat weight." % carat)
		rtl.push_color(DeepUi.ACCENT_HI)
		rtl.push_font_size(15)
		rtl.add_text("×%s " % _trim_number(base_mult))
		rtl.add_image(GemIcons.texture("carat", GemIcons.baked_size(16.0)), 15, 15, DeepUi.ACCENT_HI)
		rtl.pop_all()
	for m in mods:
		## carat_mult already rode into base_mult above (it scales the carat the curve reads,
		## not the curve's output), so only a true post-multiplier earns its own badge here.
		if not scales or str(m.get("kind", "")) != "magnitude":
			continue
		var inclusion: Dictionary = DeepContent.inclusion(str(m.get("inclusion", "")))
		var cls: String = str(inclusion.get("class", "PINPOINT"))
		var tone: Color = StoneCard.INCLUSION_TONES.get(cls, DeepUi.INFO)
		var glyph: String = str(StoneCard.INCLUSION_GLYPHS.get(cls, "spark"))
		rtl.add_text(" ")
		rtl.push_hint("%s: %s" % [str(inclusion.get("name", "")), str(inclusion.get("text", ""))])
		rtl.push_color(tone)
		rtl.push_font_size(15)
		rtl.add_text("×%s " % _trim_number(float(m.get("amount", 1.0))))
		rtl.add_image(GemIcons.texture(glyph, GemIcons.baked_size(16.0)), 15, 15, tone)
		rtl.pop_all()
	parent.add_child(rtl)

func _inclusion_note(parent: Node, mod: Dictionary, text: String) -> void:
	## What an inclusion is doing to a stat behind the scenes: its own mark and color, with
	## the inclusion's text a hover away, wherever the stat it is bending shows up on the page.
	var inclusion: Dictionary = DeepContent.inclusion(str(mod.get("inclusion", "")))
	var cls: String = str(inclusion.get("class", "PINPOINT"))
	var tone: Color = StoneCard.INCLUSION_TONES.get(cls, DeepUi.INFO)
	var glyph: String = str(StoneCard.INCLUSION_GLYPHS.get(cls, "spark"))
	DeepUi.stat(parent, glyph, "%s %s" % [str(inclusion.get("name", "")), text], tone, 12, str(inclusion.get("text", "")))

func _trim_number(value: float) -> String:
	var text := "%.2f" % value
	text = text.rstrip("0")
	return text.rstrip(".")

# --- the grade pill's popup ----------------------------------------------------------------

func _open_reveal(item: Dictionary) -> void:
	## A second click while the last run is still animating must not let a late callback
	## reach into a row this call is about to free, so every tracked tween dies first.
	_kill_reveal_tweens()
	if not _pages.is_empty():
		_pages[0].box.visible = false
	if _reveal == null:
		_reveal = DeepUi.center(_book)
		_reveal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_reveal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		DeepUi.clear(_reveal)
	_reveal.visible = true
	DeepAudio.play("ui_open", {"volume": 0.5})
	var inner := DeepUi.vbox(_reveal, 12)
	_animate_reveal(inner, item)

func _close_reveal() -> void:
	_kill_reveal_tweens()
	if _reveal != null:
		_reveal.visible = false
	if not _pages.is_empty():
		_pages[0].box.visible = true
	DeepAudio.play("ui_close", {"volume": 0.5})

func _reveal_tween() -> Tween:
	var t := create_tween()
	_reveal_tweens.append(t)
	return t

func _kill_reveal_tweens() -> void:
	for t in _reveal_tweens:
		if t != null and t.is_valid():
			t.kill()
	_reveal_tweens.clear()

func _animate_reveal(root: VBoxContainer, item: Dictionary) -> void:
	## Carat, Cut and Clarity count and fill in one after another, centred as one block; then
	## any inclusions, one at a time, each with what it adds to the grade; then what the three
	## C's and the skill's own rarity are worth; then the total, the grade flying in large,
	## the gold, and a way back out.
	var grade: Dictionary = DeepStone.grade(item)
	var breakdown: Dictionary = grade.get("breakdown", {})
	var raw_carat: int = int(item.get("carat", 1))
	var raw_cut: int = int(item.get("cut", 0))
	var clarity: int = int(item.get("clarity", 3))
	_reveal_row(root, "carat", "Carat", raw_carat, 1, float(raw_carat) / float(DeepStone.carat_max()), DeepUi.ACCENT, 0.0)
	_reveal_row(root, "cut", "Cut", -1, 0, float(raw_cut + 1) / 5.0, DeepUi.ACCENT, 0.5, DeepContent.cut_name(raw_cut))
	_reveal_row(root, "clarity", "Clarity", -1, 0, float(clarity + 1) / 6.0, DeepUi.ACCENT, 1.0, DeepContent.clarity_name(clarity))
	var at: float = 1.6
	var inclusions: Array = item.get("inclusions", [])
	if not inclusions.is_empty():
		var label := DeepUi.label(root, "Inclusions", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label.modulate.a = 0.0
		var heading_delay: float = at
		var t0 := _reveal_tween()
		t0.tween_interval(heading_delay)
		t0.tween_callback(func() -> void:
			if is_instance_valid(label):
				DeepUi.pop_in(label, 0.0, 0.9, 0.2))
		at += 0.25
		for key in inclusions:
			_inclusion_reveal_row(root, str(key), at)
			at += 0.3
		at += 0.2
	## What each is worth toward the grade, staggered a little after the values above settle.
	var contrib := DeepUi.vbox(root, 4)
	contrib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lines: Array = [["Carat", float(breakdown.get("carat_pts", 0.0))], ["Cut", float(breakdown.get("cut_pts", 0.0))],
		["Clarity", float(breakdown.get("clarity_pts", 0.0))], ["Rarity", float(breakdown.get("skill_pts", 0.0))]]
	const CONTRIB_STEP := 0.15
	for index in range(lines.size()):
		var line_row := DeepUi.hbox(contrib, 8)
		line_row.modulate.a = 0.0
		var name_label := DeepUi.label(line_row, str(lines[index][0]), 12, DeepUi.MUTED)
		name_label.custom_minimum_size.x = 70
		var pts_label := DeepUi.label(line_row, "0.0 pts", 12, DeepUi.PAPER)
		var target: float = float(lines[index][1])
		var delay: float = at + float(index) * CONTRIB_STEP
		var t := _reveal_tween()
		t.tween_interval(delay)
		t.tween_callback(func() -> void:
			if not is_instance_valid(line_row) or not is_instance_valid(pts_label):
				return
			DeepUi.pop_in(line_row, 0.0, 0.92, 0.22)
			_count_up_float(pts_label, 0.0, target, 0.4, " pts"))
	at += float(lines.size()) * CONTRIB_STEP + 0.5
	## The total, then the grade flying in large, then the gold, then a way back out.
	var total_row := DeepUi.hbox(root, 10)
	total_row.modulate.a = 0.0
	total_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DeepUi.label(total_row, "Total", 15, DeepUi.MUTED)
	var total_label := DeepUi.title(total_row, "0", 26, DeepUi.PAPER)
	var total_start: float = at
	var t2 := _reveal_tween()
	t2.tween_interval(total_start)
	t2.tween_callback(func() -> void:
		if not is_instance_valid(total_row) or not is_instance_valid(total_label):
			return
		DeepUi.pop_in(total_row, 0.0, 0.9, 0.25)
		_count_up(total_label, 0, int(grade.score), 0.5))
	var finale := DeepUi.center(root)
	finale.modulate.a = 0.0
	var finale_box := DeepUi.vbox(finale, 6)
	var tier: Color = DeepUi.tier_color(str(grade.tier))
	var grade_label := DeepUi.title(finale_box, str(grade.name), 40, tier, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.label(finale_box, "%d gold" % DeepStone.value(item), 18, DeepUi.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	var finale_start: float = total_start + 0.8
	var t3 := _reveal_tween()
	t3.tween_interval(finale_start)
	t3.tween_callback(func() -> void:
		if not is_instance_valid(finale) or not is_instance_valid(grade_label):
			return
		finale.modulate.a = 1.0
		grade_label.pivot_offset = grade_label.size * 0.5
		grade_label.scale = Vector2.ONE * 0.5
		grade_label.modulate.a = 0.0
		var fly := _reveal_tween()
		fly.set_parallel(true)
		fly.tween_property(grade_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fly.tween_property(grade_label, "modulate:a", 1.0, 0.3)
		DeepAudio.play("ui_confirm", {"volume": 0.6}))
	var again := DeepUi.center(root)
	again.modulate.a = 0.0
	var continue_label := DeepUi.label(again, "Click to continue", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	continue_label.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_label.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_reveal())
	var continue_start: float = finale_start + 0.7
	var t4 := _reveal_tween()
	t4.tween_interval(continue_start)
	t4.tween_callback(func() -> void:
		if not is_instance_valid(again) or not is_instance_valid(continue_label):
			return
		again.modulate.a = 1.0
		DeepUi.breathe(continue_label, 0.5, 1.4))

func _reveal_row(parent: Node, glyph: String, name: String, numeric_target: int, from_value: int, share: float, tone: Color, delay: float, text_value: String = "") -> void:
	var row := DeepUi.hbox(parent, 10)
	row.modulate.a = 0.0
	DeepUi.icon(row, glyph, 22, tone, GemIcons.hint(glyph))
	var label := DeepUi.label(row, name, 14, DeepUi.MUTED)
	label.custom_minimum_size.x = 64
	var value := DeepUi.title(row, "", 20, DeepUi.PAPER)
	value.custom_minimum_size.x = 90
	var meter := DeepUi.bar(row, 10.0, tone, Color(DeepUi.LINE, 0.7))
	meter.custom_minimum_size = Vector2(160, 10)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.set_values(0.0)
	DeepUi.pop_in(row, delay, 0.9, 0.3)
	var t := _reveal_tween()
	t.tween_interval(delay + 0.1)
	t.tween_callback(func() -> void:
		if not is_instance_valid(meter) or not is_instance_valid(value):
			return
		meter.set_values(clampf(share, 0.0, 1.0))
		if numeric_target >= 0:
			_count_up(value, from_value, numeric_target, 0.5)
		else:
			value.text = text_value
			DeepUi.pulse(value, 1.15, 0.3))

func _inclusion_reveal_row(parent: Node, key: String, delay: float) -> void:
	var inclusion: Dictionary = DeepContent.inclusion(key)
	var cls: String = str(inclusion.get("class", "PINPOINT"))
	var tone: Color = StoneCard.INCLUSION_TONES.get(cls, DeepUi.INFO)
	var glyph: String = str(StoneCard.INCLUSION_GLYPHS.get(cls, "spark"))
	var score: float = float(DeepStone.INCLUSION_SCORE.get(str(inclusion.get("rarity", "COMMON")), 2.0))
	var row := DeepUi.hbox(parent, 8)
	row.modulate.a = 0.0
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.tooltip_text = str(inclusion.get("text", ""))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	DeepUi.icon(row, glyph, 16, tone, str(inclusion.get("text", "")))
	var name_label := DeepUi.label(row, str(inclusion.get("name", key)), 13, DeepUi.PAPER)
	name_label.custom_minimum_size.x = 110
	var sign: String = "+" if score >= 0.0 else ""
	DeepUi.label(row, "%s%s pts" % [sign, _trim_number(score)], 13, tone)
	var t := _reveal_tween()
	t.tween_interval(delay)
	t.tween_callback(func() -> void:
		if is_instance_valid(row):
			DeepUi.pop_in(row, 0.0, 0.9, 0.25))

func _count_up(label: Label, from: int, to: int, seconds: float) -> void:
	if not is_instance_valid(label):
		return
	if DeepUi.headless():
		label.text = str(to)
		return
	var apply := func(v: float) -> void:
		if is_instance_valid(label):
			label.text = str(int(round(v)))
	var t := _reveal_tween()
	t.tween_method(apply, float(from), float(to), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _count_up_float(label: Label, from: float, to: float, seconds: float, suffix: String) -> void:
	if not is_instance_valid(label):
		return
	if DeepUi.headless():
		label.text = "%.1f%s" % [to, suffix]
		return
	var apply := func(v: float) -> void:
		if is_instance_valid(label):
			label.text = "%.1f%s" % [v, suffix]
	var t := _reveal_tween()
	t.tween_method(apply, from, to, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _fill_birthstone(item: Dictionary) -> void:
	## A Birthstone is fixed: no grade, no price and no four C's to weigh. What matters is
	## what each tier asks of the hand and what it does, and whose stone it is.
	var view := GemView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	view.set_slot(220.0)
	view.set_drift(true)
	view.set_spin(0.35)
	view.configure(item)
	view.enable_interaction()
	_stage.add_child(view)
	var tint: Color = GemMesh.tint(item)
	var character_key: String = str(item.get("character", ""))
	var character: Dictionary = DeepContent.character(character_key)
	var head := _head
	DeepUi.title(head, str(item.get("name", "")), 28, tint.lightened(0.35))
	var tags := DeepUi.hbox(head, 8)
	DeepUi.pill(tags, "crown", "%s's Birthstone" % str(character.get("name", character_key)), tint.lightened(0.3), 13)
	DeepUi.pill(tags, "lock", "Always set, last in the rail", DeepUi.MUTED, 13)
	DeepUi.wrap(head, str(item.get("text", "")), 14, DeepUi.MUTED)
	var tiers: Array = item.get("tiers", [])
	_page("Its tiers", "cut")
	var how := _section("spark", "How it fires")
	var rule: String = "After every gem has had its turn, it reads the Resonance your rail built. Every tier your final hand satisfies fires on that Resonance."
	if tiers.any(func(t: Dictionary) -> bool: return bool(t.get("exclusive", false))):
		rule += " An exclusive tier that fires takes the others' place."
	DeepUi.effect_text(how, rule, 13, DeepUi.PAPER)
	## Every tier: the hand it asks for, drawn and said, and what it does.
	var box := _section("cut", "Its tiers" if tiers.size() > 1 else "Its tier")
	var die: String = DiceIcons.ladder_die(tiers)
	for tier in tiers:
		var penalty: bool = bool(tier.get("penalty", false))
		var tone: Color = DeepUi.BAD if penalty else tint.lightened(0.3)
		var line := DeepUi.panel(box, Color(tone, 0.07), Color(tone, 0.35), 8, 8)
		var cells := DeepUi.hbox(line, 14)
		var mark := DeepUi.center(cells)
		mark.custom_minimum_size.x = 100
		var described: Dictionary = DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0)
		var rung: int = DiceIcons.ladder_rung(tier, die)
		if rung > 0:
			DiceIcons.build_ladder(mark, [tier], die, rung, 18, DeepUi.PAPER, DeepUi.DIM)
		else:
			DiceIcons.build(mark, described, 20, DeepUi.PAPER, str(described.get("words", "")))
		var words := DeepUi.vbox(cells, 2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_row := DeepUi.hbox(words, 8)
		DeepUi.title(name_row, str(tier.get("name", "")), 17, DeepUi.PAPER)
		if penalty:
			DeepUi.chip(name_row, "Costs you", DeepUi.BAD, 11)
		if bool(tier.get("exclusive", false)):
			DeepUi.chip(name_row, "Exclusive", DeepUi.ACCENT, 11)
		## Every tier's text opens with the hand it needs, so the sentence is not said twice.
		DeepUi.effect_text(words, str(tier.get("text", "")), 13, DeepUi.PAPER)
	## The rest of what the lapidary brings down with it.
	var passive: Dictionary = character.get("passive", {})
	if not passive.is_empty():
		var own := _section("person", "%s's passive" % str(character.get("name", character_key)))
		DeepUi.title(own, str(passive.get("name", "")), 17, DeepUi.ACCENT_HI)
		DeepUi.effect_text(own, str(passive.get("text", "")), 13, DeepUi.PAPER)

func _clarity_words(clarity: int) -> String:
	match clarity:
		5: return "Hits half as hard again, rings the rail for three times the Resonance, and has its Flawless line."
		4: return "Rings the rail for twice the Resonance whenever it fires."
		3: return "An honest stone with nothing frozen inside."
	return "Carries %s, the quirks that make one stone unlike another." % DeepUi.plural(DeepStone.inclusion_slots(clarity), "inclusion")

func _inclusions(item: Dictionary, parent: Control) -> void:
	if item.get("inclusions", []).is_empty():
		return
	## A grid, not a row per inclusion: the name column sizes to its widest pill, so every
	## description lines up under the last one instead of staggering with the name's length.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for key in item.inclusions:
		var inclusion: Dictionary = DeepContent.inclusion(str(key))
		var cls: String = str(inclusion.get("class", "PINPOINT"))
		var tone: Color = StoneCard.INCLUSION_TONES.get(cls, DeepUi.INFO)
		var badge := DeepUi.pill(grid, str(StoneCard.INCLUSION_GLYPHS.get(cls, "spark")), str(inclusion.get("name", key)), tone, 13)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var words := DeepUi.wrap(grid, str(inclusion.get("text", "")), 13, DeepUi.PAPER)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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
	var head := _head
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
	var paged := faces.size() > 30
	var grid: HFlowContainer
	var values: Array = []
	var kinds: Dictionary = {}
	for index in range(faces.size()):
		if index % 30 == 0:
			var title := "%d–%d" % [index + 1, mini(index + 30, faces.size())] if paged else "Its faces"
			_page(title, "die")
			var face_box := _section("die", "Faces " + title if paged else title)
			grid = HFlowContainer.new()
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			face_box.add_child(grid)
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
	if paged:
		_page("About", "hourglass")
	for kind in kinds:
		DeepUi.stat(_details, "spark", str(FACE_TEXT.get(kind, kind)), DiceIcons.face_kind_tint(str(kind)).lightened(0.2), 13)
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
	var head := _head
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
	## What is on it and what it means to do: the page for this turn, when there is one.
	var effects: Array = EffectChips.for_enemy(foe, battle) if foe.has("hp") else []
	if not effects.is_empty():
		var chips := EffectChips.Row.new(18)
		head.add_child(chips)
		chips.show_effects(effects)
	if not effects.is_empty() or not foe.get("hand", []).is_empty():
		_page("This turn", "sword")
	if not effects.is_empty():
		var notes := _section("spark", "On it now")
		for effect in effects:
			DeepUi.stat(notes, str(effect.glyph), "%s: %s" % [str(effect.title), str(effect.text)], Color(effect.tone).lightened(0.2), 12)
	if not foe.get("hand", []).is_empty():
		var now := _section("die", "Revealed dice", DeepUi.BAD)
		var dice := DeepUi.hbox(now, 4)
		var shown: Array = foe.hand.slice(0, -1) if str(foe.get("beat", "")) == "roll" else foe.hand
		for roll in shown:
			dice.add_child(DiceIcons.face(26, int(roll.value), DiceIcons.palette(str(roll.get("key", "D6"))).body, str(roll.get("shape", "D6")), true))
	_page("Its moves", "book")
	var moves := _section("book", "Its moves")
	var highlight: String = str(opts.get("move", ""))
	for move in DeepCreatures.display_moves(foe, definition.get("moves", [])):
		_move_row(moves, move, str(move.get("name", "")) == highlight)
	for phase in definition.get("phases", []):
		_page("Below %d%% HP" % int(phase.get("below_hp_pct", 0)), "crown")
		moves = _section("crown", "Phase moves")
		DeepUi.stat(moves, "crown", "Below %d%% health it fights with:" % int(phase.get("below_hp_pct", 0)), DeepUi.BAD, 13)
		for move in DeepCreatures.display_moves(foe, phase.get("moves", [])):
			_move_row(moves, move, str(move.get("name", "")) == highlight)
	var rolls := _section("die", "Its dice")
	var dice_row := DeepUi.hbox(rolls, 6)
	var effective: Array = DeepCreatures.effective_dice(foe) if foe.has("dice") else definition.get("dice", []).map(func(key: String) -> Dictionary: return {"shape": key})
	for die in effective:
		DeepUi.pill(dice_row, "die", str(die.shape), DiceIcons.palette(str(die.shape)).body, 12)
	DeepUi.label(rolls, "Rolls in this order. Every qualifying ability fires.\nDamage and debuffs affect every player.", 12, DeepUi.DIM)

static func _dice_words(keys: Array) -> String:
	## A set of five dice said the short way: each kind once, by name, with how many of it.
	## Florin comes down with five of one die, and five copies of the same key spelled out
	## would take the pill clean across the page.
	var order: Array = []
	var counts: Dictionary = {}
	for key in keys:
		var name: String = str(DeepContent.die(str(key)).get("name", key))
		if not counts.has(name):
			order.append(name)
		counts[name] = int(counts.get(name, 0)) + 1
	var parts: Array = []
	for name in order:
		parts.append(str(name) if int(counts[name]) <= 1 else "%s ×%d" % [str(name), int(counts[name])])
	return ", ".join(parts)

func _move_row(parent: Node, move: Dictionary, highlight: bool) -> void:
	var panel := DeepUi.panel(parent, Color(DeepUi.BAD, 0.12) if highlight else Color(1, 1, 1, 0.03), Color(DeepUi.BAD, 0.6) if highlight else Color(0, 0, 0, 0), 8, 8)
	var box := DeepUi.vbox(panel, 4)
	var head := DeepUi.hbox(box, 10)
	DeepUi.icon(head, GemIcons.emblem(str(move.get("name", "")).to_upper()), 20, DeepUi.BAD if highlight else DeepUi.MUTED)
	DeepUi.title(head, str(move.get("name", "")), 16, DeepUi.PAPER)
	DeepUi.label(box, DeepCreatures.trigger_words(move), 12, DeepUi.DIM)
	for effect in move.get("effects", []):
		DeepUi.stat(box, _effect_glyph(str(effect.get("kind", ""))), DeepCreatures.effect_words(effect), DeepUi.PAPER, 13)

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
		return str(int(expr.const ))
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

func _fill_lapidary(character_key: String, tone: Color) -> void:
	## The plate fills the light, the Birthstone turns in front of it at the corner, and the
	## page beside them is written one line at a time.
	var character: Dictionary = DeepContent.character(character_key)
	var stone: Dictionary = DeepStone.birthstone(character_key)
	var portrait: Control = load("res://view/home/roster.gd").Portrait.new(character_key, Vector2(320, 380), false, false, true)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 16)
	portrait.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stage.add_child(portrait)
	var gem_holder: Control = null
	if not stone.is_empty():
		## Small, in front of the plate and low to one side, the way a stone is held up to
		## the light beside the person whose it is.
		gem_holder = Control.new()
		gem_holder.custom_minimum_size = Vector2(180, 180)
		gem_holder.size = Vector2(180, 180)
		gem_holder.mouse_filter = Control.MOUSE_FILTER_PASS
		_stage.add_child(gem_holder)
		gem_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 6)
		gem_holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		gem_holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
		var view := GemView.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.set_slot(150.0)
		view.set_drift(true)
		view.set_spin(0.5)
		view.configure(stone)
		view.enable_interaction()
		view.inspectable = false
		gem_holder.add_child(view)
	## The page: one section at a time, each waiting on the one before it.
	var reveals: Array = []
	var name_row := DeepUi.hbox(_head, 10)
	DeepUi.title(name_row, str(character.get("name", character_key)), 40, tone.lightened(0.4))
	var title: String = str(character.get("title", ""))
	if not title.is_empty():
		DeepUi.pill(name_row, "person", title, tone.lightened(0.2), 14).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.gap(_head, 2)
	var blurb := DeepUi.wrap(_head, str(character.get("text", "")), 15, DeepUi.PAPER)
	blurb.custom_minimum_size.x = 560
	reveals.append(blurb)
	var page := _page("", "")
	page.add_theme_constant_override("separation", 18)
	var stats := DeepUi.hbox(page, 14)
	DeepUi.pill(stats, "heart", "%d health" % int(character.get("hp", 0)), DeepUi.HP, 14)
	DeepUi.pill(stats, "gem", "%s" % DeepUi.plural(character.get("sockets", []).size(), "socket"), DeepUi.ACCENT, 14)
	DeepUi.pill(stats, "die", _dice_words(character.get("dice", [])), DeepUi.INFO, 14)
	reveals.append(stats)
	var passive: Dictionary = character.get("passive", {})
	if not passive.is_empty():
		var own := DeepUi.vbox(page, 6)
		DeepUi.section(own, "spark", "Their gift", DeepUi.ACCENT_HI)
		DeepUi.title(own, str(passive.get("name", "")), 20, DeepUi.ACCENT_HI)
		DeepUi.effect_text(own, str(passive.get("text", "")), 15, DeepUi.PAPER).custom_minimum_size.x = 560
		reveals.append(own)
	if not stone.is_empty():
		var birth := DeepUi.vbox(page, 6)
		DeepUi.section(birth, "crown", "Their Birthstone", tone.lightened(0.3))
		DeepUi.title(birth, str(stone.get("name", "")), 20, tone.lightened(0.35))
		DeepUi.wrap(birth, str(stone.get("text", "")), 15, DeepUi.PAPER).custom_minimum_size.x = 560
		for tier in stone.get("tiers", []):
			var line := DeepUi.hbox(birth, 8)
			DeepUi.icon(line, "cut", 15, tone.lightened(0.2)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var said := DeepUi.effect_text(line, "%s — %s" % [str(tier.get("name", "")), str(tier.get("text", ""))], 13, DeepUi.MUTED)
			said.custom_minimum_size.x = 530
			said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reveals.append(birth)
	if DeepUi.headless():
		return
	## The slow reveal: the plate comes up out of the dark, the stone lights beside it, and
	## then each part of the page is written in turn.
	portrait.modulate.a = 0.0
	portrait.scale = Vector2(1.06, 1.06)
	portrait.pivot_offset = portrait.size * 0.5
	if gem_holder != null:
		gem_holder.modulate.a = 0.0
	for part in reveals:
		(part as Control).modulate.a = 0.0
	if _close != null:
		_close.modulate.a = 0.0
		_close.disabled = true
	var reveal := create_tween()
	reveal.tween_interval(0.35)
	reveal.tween_property(portrait, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	reveal.parallel().tween_property(portrait, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if gem_holder != null:
		reveal.tween_callback(func() -> void:
			DeepAudio.play("gleam", {"volume": 0.8})
			if _rays != null and is_instance_valid(_rays):
				DeepUi.burst(_rays, _rays.size * 0.5 - Vector2(250, 40), tone.lightened(0.35), 50, 380.0, 1.1, 7.0))
		reveal.tween_property(gem_holder, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	for part in reveals:
		var shown: Control = part
		reveal.tween_interval(0.22)
		reveal.tween_callback(func() -> void:
			DeepAudio.play("ui_tab", {"volume": 0.45})
			if is_instance_valid(shown):
				DeepUi.pop_in(shown, 0.0, 0.98, 0.3))
		reveal.tween_property(shown, "modulate:a", 1.0, 0.3)
	if _close != null:
		reveal.tween_callback(func() -> void:
			if is_instance_valid(_close):
				_close.disabled = false
				DeepUi.breathe(_close, 0.7, 1.5))
		reveal.tween_property(_close, "modulate:a", 1.0, 0.35)

func _fill_announcement(text: String, glyph: String, tone: Color) -> void:
	var mark := DeepUi.center(_stage)
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DeepUi.icon(mark, glyph, 180, tone.lightened(0.25))
	DeepUi.wrap(_page("", ""), text, 18, DeepUi.PAPER).custom_minimum_size.x = 520

# --- light -------------------------------------------------------------------------------------

class Halo extends Control:
	## The pool of light the inspected thing stands in.
	var tone: Color
	var _clock: float = 0.0
	func _init(color: Color) -> void:
		tone = color
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
	## God rays wheeling behind a won thing, from where it stands: `offset` from the middle.
	var tone: Color
	var offset := Vector2(-250, -20)
	var _clock: float = 0.0
	func _init(color: Color) -> void:
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()
	func _draw() -> void:
		var centre := size * 0.5 + offset
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
