extends Control
## A workbench for the gems: pick a skill, move its three ranks, and watch the stone.
##
##   godot --path . scenes/gem_lab.tscn
##
## Nothing here is part of the game. It exists because the four C's are a visual language
## and the only way to know whether that language reads is to sweep one property at a time
## and look. It shows the live solid, the same name line and rule chain the game shows,
## and the numbers underneath them, so a change to `gem_mesh.gd` can be judged in seconds
## instead of by rebuilding a contact sheet.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const GemView = preload("res://scripts/ui/gem_view.gd")
const GemMesh = preload("res://scripts/ui/gem_mesh.gd")
const GemPanel = preload("res://scripts/ui/gem_panel.gd")
const GemText = preload("res://scripts/ui/gem_text.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const Tuning = preload("res://scripts/ui/gem_tuning.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")

const SPIN := 0.7
## The box the stone is measured against here, small enough that a Carat 24 gem overflowing
## it by half still lands inside the stage.
const SLOT := 300.0
## What to stand the stone against. Transparency only means something relative to what is
## behind it, so the first two are the panels gems actually sit on in the game, the
## checker is the honest test of the alpha, and the rest are the extremes it has to
## survive — a light ground washes a pale stone out, a saturated one fights its hue.
const BACKDROPS := [
	{"name": "Game panel", "fill": Color("161e2e")},
	{"name": "Battle card", "fill": Color("18302c")},
	{"name": "Void", "fill": Color("070a12")},
	{"name": "Checker", "fill": Color("9aa3b0"), "checker": Color("6e7684")},
	{"name": "Mid grey", "fill": Color("848c96")},
	{"name": "Paper", "fill": Color("f2f3f5")},
	{"name": "Deep red", "fill": Color("6d1420")}]

var keys: Array = []
var index := 0
var carat := 12
var cut := 3
var clarity := 4
var spinning := false
var backdrop_index := 0

var _view: GemView
var _title: VBoxContainer
var _rule: VBoxContainer
var _facts: VBoxContainer
var _skill_label: Label
var _rows: Dictionary = {}
var _stage_back: Control
var _swatches: Array = []
var _grounds: Dictionary = {}
var _slot_mark: Control
var _knobs: Dictionary = {}
var _tuning_state: Label

func _ready() -> void:
	keys = Catalog.SKILLS.keys()
	keys.sort()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.build_theme(1.0)
	var backdrop := ColorRect.new()
	backdrop.color = UiKit.VOID
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		page.add_theme_constant_override("margin_" + edge, 22)
	add_child(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	page.add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	GemPanel.word(heading, "GEM LAB", 26, UiKit.GOLD)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	GemPanel.word(heading, "← → skill    ↑ ↓ carat    [ ] cut    ; ' clarity    B ground    T reset knobs    R random    S spin    Esc quit",
		13, UiKit.MUTED)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	# --- the stone ------------------------------------------------------------
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(460, 460)
	stage.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.PANEL, UiKit.PANEL_LOW, UiKit.LINE, 12, 10, 1.4, 0.2))
	body.add_child(stage)
	_stage_back = Control.new()
	_stage_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_back.draw.connect(_draw_backdrop)
	stage.add_child(_stage_back)
	# The view fills the stage so its ground does too, and the stone is measured against a
	# smaller slot marked out inside it. That way a Carat 24 gem can be seen hanging over
	# the edges of its setting without hanging over the dials.
	_view = GemView.new()
	_view.custom_minimum_size = Vector2(440, 440)
	stage.add_child(_view)
	_view.set_slot(SLOT)
	_view.enable_interaction()
	_slot_mark = Control.new()
	_slot_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_mark.draw.connect(_draw_slot)
	stage.add_child(_slot_mark)

	# --- the dials ------------------------------------------------------------
	# Behind a scroll of their own: the stack of them is taller than a short window, and
	# without this it pushed the rule chain off the bottom of the page.
	var dial_scroll := ScrollContainer.new()
	dial_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dial_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(dial_scroll)
	var dials := VBoxContainer.new()
	dials.add_theme_constant_override("separation", 12)
	dials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dial_scroll.add_child(dials)

	var skill_box := _framed(dials, "SKILL")
	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 10)
	skill_box.add_child(skill_row)
	_step_button(skill_row, "◀", func() -> void: _cycle(-1))
	_skill_label = GemPanel.word(skill_row, "", 21, UiKit.PAPER)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_button(skill_row, "▶", func() -> void: _cycle(1))

	_dial(dials, "carat", "CARAT", 1, 24)
	_dial(dials, "cut", "CUT", 1, 5)
	_dial(dials, "clarity", "CLARITY", 1, 5)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	dials.add_child(buttons)
	_wide_button(buttons, "Randomise  [R]", func() -> void: _randomise())
	_wide_button(buttons, "Spin  [S]", func() -> void: _toggle_spin())
	_wide_button(buttons, "Face on", func() -> void: _view.rest())

	var ground := _framed(dials, "BEHIND THE STONE  [B]")
	var swatch_row := HBoxContainer.new()
	swatch_row.add_theme_constant_override("separation", 7)
	ground.add_child(swatch_row)
	for slot in range(BACKDROPS.size()):
		_swatches.append(_swatch(swatch_row, slot))

	_facts = _framed(dials, "THIS STONE")

	# --- the material and the room it stands in --------------------------------
	_tuning_column(body)

	# --- what the game would say ----------------------------------------------
	var readout := PanelContainer.new()
	readout.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.PANEL, UiKit.PANEL_LOW, UiKit.LINE, 11, 14, 1.4, 0.18))
	column.add_child(readout)
	var readout_column := VBoxContainer.new()
	readout_column.add_theme_constant_override("separation", 8)
	readout.add_child(readout_column)
	_title = VBoxContainer.new()
	readout_column.add_child(_title)
	_rule = VBoxContainer.new()
	_rule.add_theme_constant_override("separation", 5)
	readout_column.add_child(_rule)

	_set_backdrop(backdrop_index)
	_paint_knobs()
	_refresh()

# --- widgets ------------------------------------------------------------------

func _framed(parent: Node, caption: String) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.PANEL, UiKit.PANEL_LOW, UiKit.LINE, 10, 12, 1.4, 0.18))
	parent.add_child(frame)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 7)
	frame.add_child(inner)
	GemPanel.word(inner, caption, 11, UiKit.GOLD)
	return inner

func _swatch(parent: Node, slot: int) -> Button:
	## A sample of the ground itself, so picking one needs no reading.
	var entry: Dictionary = BACKDROPS[slot]
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = str(entry.name)
	button.pressed.connect(func() -> void: _set_backdrop(slot))
	parent.add_child(button)
	return button

func _tuning_column(parent: Node) -> void:
	## Every material and lighting number, live. This is the whole point of the lab: the
	## stone is judged by eye, so the numbers that decide it have to be under the eye.
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(336, 0)
	frame.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.PANEL, UiKit.PANEL_LOW, UiKit.LINE, 10, 12, 1.4, 0.18))
	parent.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	frame.add_child(column)

	var head := HBoxContainer.new()
	column.add_child(head)
	GemPanel.word(head, "MATERIAL & LIGHT", 11, UiKit.GOLD)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gap)
	_tuning_state = GemPanel.word(head, "", 11, UiKit.MUTED)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var groups: Array = Tuning.groups()
	for slot in range(groups.size()):
		if slot > 0:
			UiKit.rule(list, Color(UiKit.LINE, 0.7))
		GemPanel.word(list, str(groups[slot]), 10, Color(UiKit.GOLD, 0.75))
		for knob: Dictionary in Tuning.in_group(str(groups[slot])):
			_knob(list, knob)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_wide_button(buttons, "Reset  [T]", func() -> void: _reset_tuning())
	_wide_button(buttons, "Copy values", func() -> void: _copy_tuning())

func _knob(parent: Node, knob: Dictionary) -> void:
	## One number: what it is called, where it currently sits, and the range worth sweeping.
	## The whole row carries the explanation, so hovering anywhere on it says what it does.
	var key := str(knob.key)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.tooltip_text = "%s\n%s" % [str(knob.label), str(knob.hint)]
	parent.add_child(box)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var caption := GemPanel.word(head, str(knob.label), 11, UiKit.MUTED)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gap)
	var readout := GemPanel.word(head, "", 11, UiKit.PAPER)

	var control: Control
	if _is_flag(knob):
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.custom_minimum_size = Vector2(52, 20)
		toggle.add_theme_font_size_override("font_size", 11)
		toggle.tooltip_text = box.tooltip_text
		toggle.toggled.connect(func(on: bool) -> void: _set_knob(key, 1.0 if on else 0.0))
		head.add_child(toggle)
		readout.hide()
		control = toggle
	else:
		var slider := HSlider.new()
		slider.min_value = float(knob.low)
		slider.max_value = float(knob.high)
		slider.step = float(knob.step)
		slider.focus_mode = Control.FOCUS_NONE
		slider.custom_minimum_size = Vector2(0, 18)
		slider.tooltip_text = box.tooltip_text
		slider.add_theme_stylebox_override("slider", UiKit.flat(Color(UiKit.VOID, 0.9), Color(UiKit.LINE, 0.9), 4, 3, 1))
		slider.add_theme_stylebox_override("grabber_area", UiKit.flat(Color(UiKit.GOLD_DIM, 0.55), Color(UiKit.GOLD_DIM, 0.85), 4, 3, 1))
		slider.add_theme_stylebox_override("grabber_area_highlight", UiKit.flat(Color(UiKit.GOLD, 0.7), UiKit.GOLD, 4, 3, 1))
		slider.value_changed.connect(func(amount: float) -> void: _set_knob(key, amount))
		box.add_child(slider)
		control = slider
	_knobs[key] = {"knob": knob, "caption": caption, "readout": readout, "control": control}

func _is_flag(knob: Dictionary) -> bool:
	return is_equal_approx(float(knob.step), 1.0) and is_equal_approx(float(knob.high), 1.0)

func _step_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(46, 0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _wide_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _dial(parent: Node, property: String, caption: String, low: int, high: int) -> void:
	## A rank and the two ways to change it: the arrows for one step, the slider for a sweep.
	var box := _framed(parent, caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var tint: Color = GemPanel.PROPERTY_TINTS[property]
	GemIcons.glyph(row, property, 24, tint, GemIcons.hint(property))
	_step_button(row, "◀", func() -> void: _nudge(property, -1))
	var value := GemPanel.word(row, "", 21, tint)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_button(row, "▶", func() -> void: _nudge(property, 1))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 1
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The shared theme draws the track almost the colour of the panel, which is right in a
	# settings menu and invisible here where the slider is the main control. Filling it in
	# the property's own colour also shows how far along its range the rank sits.
	slider.custom_minimum_size = Vector2(0, 22)
	slider.add_theme_stylebox_override("slider", UiKit.flat(Color(UiKit.VOID, 0.9), Color(UiKit.LINE, 0.9), 5, 4, 1))
	slider.add_theme_stylebox_override("grabber_area", UiKit.flat(Color(tint, 0.55), Color(tint, 0.8), 5, 4, 1))
	slider.add_theme_stylebox_override("grabber_area_highlight", UiKit.flat(Color(tint, 0.75), tint, 5, 4, 1))
	box.add_child(slider)
	slider.value_changed.connect(func(amount: float) -> void: _set_rank(property, int(amount)))
	_rows[property] = {"value": value, "slider": slider}

# --- state --------------------------------------------------------------------

func _gem() -> Dictionary:
	return Catalog.gem(str(keys[index]), "lab", carat, cut, clarity)

func _rank(property: String) -> int:
	match property:
		"carat": return carat
		"cut": return cut
	return clarity

func _set_rank(property: String, amount: int) -> void:
	match property:
		"carat": carat = clampi(amount, 1, 24)
		"cut": cut = clampi(amount, 1, 5)
		"clarity": clarity = clampi(amount, 1, 5)
	_refresh()

func _nudge(property: String, step: int) -> void:
	_set_rank(property, _rank(property) + step)

func _cycle(step: int) -> void:
	index = wrapi(index + step, 0, keys.size())
	_refresh()

func _randomise() -> void:
	index = randi() % keys.size()
	carat = randi_range(1, 24)
	cut = randi_range(1, 5)
	clarity = randi_range(1, 5)
	_refresh()

func _set_backdrop(slot: int) -> void:
	backdrop_index = wrapi(slot, 0, BACKDROPS.size())
	var entry: Dictionary = BACKDROPS[backdrop_index]
	if is_instance_valid(_stage_back):
		_stage_back.queue_redraw()
	# The ground goes inside the viewport rather than behind it, which is what lets the
	# stone refract it, reflect it, and be genuinely see-through against it. The 2D draw
	# underneath stays as the fallback for a view with no ground.
	if is_instance_valid(_view):
		_view.set_ground(Color(entry.fill),
			_ground_texture(entry) if entry.has("checker") else null)
	_paint_swatches()

func _ground_texture(entry: Dictionary) -> ImageTexture:
	## A patterned ground has to be a real texture to go in the scene. Cached, because a
	## ground is swapped far more often than it is invented.
	var tag := str(entry.name)
	if _grounds.has(tag):
		return _grounds[tag]
	var span := 256
	var cell := 10
	var pale := Color(entry.fill)
	var dark := Color(entry.checker)
	var built := Image.create(span, span, false, Image.FORMAT_RGBA8)
	for y in span:
		for x in span:
			built.set_pixel(x, y, dark if ((x / cell) + (y / cell)) % 2 == 1 else pale)
	var texture := ImageTexture.create_from_image(built)
	_grounds[tag] = texture
	return texture

func _paint_swatches() -> void:
	for slot in range(_swatches.size()):
		var entry: Dictionary = BACKDROPS[slot]
		var button: Button = _swatches[slot]
		var chosen: bool = slot == backdrop_index
		var edge: Color = UiKit.GOLD if chosen else Color(UiKit.LINE, 0.9)
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state,
				UiKit.flat(entry.fill, edge, 6, 4, 3 if chosen else 1))

func _draw_backdrop() -> void:
	# A grounded view paints its own background inside the viewport, and that goes through
	# the tonemapper on the way out — so painting the same colour behind it in 2D would show
	# a near-miss rectangle rather than a seamless field. The stage frame is left plain.
	if _grounded():
		return
	var entry: Dictionary = BACKDROPS[backdrop_index]
	var area := Rect2(Vector2.ZERO, _stage_back.size)
	_stage_back.draw_rect(area, Color(entry.fill))
	if not entry.has("checker"):
		return
	# The classic alpha test: squares the stone has to sit over without hiding them.
	var cell := 18.0
	for row in range(int(ceil(_stage_back.size.y / cell))):
		for slot in range(int(ceil(_stage_back.size.x / cell))):
			if (row + slot) % 2 == 0:
				continue
			_stage_back.draw_rect(Rect2(Vector2(float(slot), float(row)) * cell,
				Vector2(cell, cell)).intersection(area), Color(entry.checker))

func _draw_slot() -> void:
	## The setting the stone is being judged against. Without it "overflowing" is a word in
	## the readout rather than something anyone can see.
	var box := Rect2((_slot_mark.size - Vector2(SLOT, SLOT)) * 0.5, Vector2(SLOT, SLOT))
	var over: bool = GemMesh.carat_span(carat) > 1.0
	_slot_mark.draw_rect(box, Color(UiKit.GOLD if over else UiKit.LINE, 0.55 if over else 0.35), false, 1.0)

func _cycle_backdrop() -> void:
	_set_backdrop(backdrop_index + 1)

func _set_knob(key: String, amount: float) -> void:
	Tuning.set_value(key, amount)
	_view.restyle()
	_paint_knobs()

func _reset_tuning() -> void:
	Tuning.reset()
	_view.restyle()
	_paint_knobs()

func _copy_tuning() -> void:
	## The changed knobs, printed and on the clipboard, ready to paste back into the table
	## in `gem_tuning.gd` — which is how a session at this bench becomes the shipped look.
	var report: String = Tuning.source_lines()
	DisplayServer.clipboard_set(report)
	print(report)

func _paint_knobs() -> void:
	## A moved knob names itself in gold, so what has been touched is visible without
	## remembering any of the defaults.
	var moved: Array = Tuning.moved()
	for key: String in _knobs:
		var row: Dictionary = _knobs[key]
		var knob: Dictionary = row.knob
		var here: float = Tuning.value(key)
		var flag: bool = _is_flag(knob)
		row.readout.text = ("on" if here > 0.5 else "off") if flag else "%.2f" % here
		var touched: bool = moved.has(key)
		row.caption.add_theme_color_override("font_color", UiKit.GOLD if touched else UiKit.MUTED)
		row.readout.add_theme_color_override("font_color", UiKit.GOLD if touched else UiKit.PAPER)
		if flag:
			var toggle: Button = row.control
			toggle.set_pressed_no_signal(here > 0.5)
			toggle.text = row.readout.text
		else:
			(row.control as HSlider).set_value_no_signal(here)
	if is_instance_valid(_tuning_state):
		_tuning_state.text = "default" if moved.is_empty() else "%d changed" % moved.size()
		_tuning_state.add_theme_color_override("font_color", UiKit.MUTED if moved.is_empty() else UiKit.GOLD)

func _toggle_spin() -> void:
	spinning = not spinning
	_view.set_spin(SPIN if spinning else 0.0)

func _refresh() -> void:
	var gem: Dictionary = _gem()
	var key: String = str(gem.key)
	var color_key: String = Catalog.gem_color(key)
	_view.configure(gem)
	if is_instance_valid(_slot_mark):
		_slot_mark.queue_redraw()
	_skill_label.text = str(Catalog.SKILLS[key].name)
	_skill_label.add_theme_color_override("font_color", GemPanel.tone(color_key))
	for property in _rows:
		var rank: int = _rank(str(property))
		var row: Dictionary = _rows[property]
		var named := str(rank)
		if property == "cut":
			named = "%d  %s" % [rank, Catalog.cut_name(rank)]
		elif property == "clarity":
			named = "%d  %s" % [rank, Catalog.clarity_name(rank)]
		row.value.text = named
		row.slider.set_value_no_signal(rank)

	for holder in [_title, _rule, _facts]:
		for child in holder.get_children():
			child.queue_free()
	# The facts panel is rebuilt too, so its caption goes back on with it.
	GemPanel.word(_facts, "THIS STONE", 11, UiKit.GOLD)
	GemPanel.title_row(_title, gem, 20, GemPanel.tone(color_key))
	GemPanel.formula_rows(_rule, gem, -1, 15)
	var definition: Dictionary = Catalog.color_definition(key)
	for line in [
			"%s — %s" % [str(definition.get("name", "Red")), str(definition.get("role", "Damage"))],
			"%s cut · %d facets · %s" % [str(GemMesh.SHAPE_NAMES.get(str(GemMesh.CUTS.get(color_key, "round")), "round")).capitalize(),
				GemMesh.facet_count(cut, color_key), GemMesh.cut_note(cut)],
			"Size %.2f of its slot%s · multiplies by %s" % [GemMesh.carat_span(carat),
				"  (overflowing)" if GemMesh.carat_span(carat) > 1.0 else "",
				GemText.number(Combat.carat_multiplier(carat))],
			"Front alpha %.2f over back %.2f · %.0f%% opaque%s" % [
				GemMesh.transparency(clarity), _back_alpha(), _opacity() * 100.0,
				"  (refraction overrides both)" if Tuning.value("refraction") > 0.001 and not _grounded() else ""],
			_flaw_line().left(1).to_upper() + _flaw_line().substr(1),
			"Trigger: " + str(Catalog.SKILLS[key].trigger)]:
		GemPanel.note(_facts, line, 13, UiKit.MUTED)

func _back_alpha() -> float:
	return lerpf(Tuning.value("far_alpha_dull"), Tuning.value("far_alpha_clear"), GemMesh.brilliance(clarity))

func _opacity() -> float:
	## How much of the background the stone actually hides — the number to watch on the
	## checker ground, because neither alpha on its own tells you. The two passes stack, and
	## refraction skips the question entirely by writing the fragment opaque.
	if Tuning.value("refraction") > 0.001 and not _grounded():
		return 1.0
	var front: float = GemMesh.transparency(clarity)
	return 1.0 - (1.0 - front) * (1.0 - _back_alpha())

func _grounded() -> bool:
	return is_instance_valid(_view) and _view.ground.a > 0.001

func _flaw_line() -> String:
	var flaws: int = GemMesh.flaw_count(clarity)
	if flaws == 0:
		return "no inclusions"
	return "%d inclusion%s" % [flaws, "" if flaws == 1 else "s"]

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_LEFT: _cycle(-1)
		KEY_RIGHT: _cycle(1)
		KEY_UP: _nudge("carat", 1)
		KEY_DOWN: _nudge("carat", -1)
		KEY_BRACKETRIGHT: _nudge("cut", 1)
		KEY_BRACKETLEFT: _nudge("cut", -1)
		KEY_APOSTROPHE: _nudge("clarity", 1)
		KEY_SEMICOLON: _nudge("clarity", -1)
		KEY_R: _randomise()
		KEY_S: _toggle_spin()
		KEY_B: _cycle_backdrop()
		KEY_T: _reset_tuning()
		_: return
	accept_event()

func _exit_tree() -> void:
	UiKit.release()
	GemIcons.release()
	GemMesh.release()
