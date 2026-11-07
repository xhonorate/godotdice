extends RefCounted
## Instant tooltips, anchored to the thing they explain. The engine's own tooltip appears
## where the pointer is, after a wait, and says one string; these appear the moment the
## pointer arrives, over (or under) the control itself, and can hold anything: a gem's
## pictograph and keyword-colored text, a die's faces, a creature's move. One plate shows at
## a time. It goes when the pointer leaves, and it is never pinned.
##
## `attach(control, build)` wires a control; `build` is called on every show and returns
## the plate's content. A plate built with `keep` stays while the pointer is on the plate
## itself, so a number inside it can be hovered for its working.

const Plate = preload("res://view/ui/tip_plate.gd")

## How long a plate takes to come and go, in seconds (the review's 90 ms in, 60 ms out).
const FADE_IN: float = 0.09
const FADE_OUT: float = 0.06
## The gap between a plate and the thing it is anchored to.
const GAP: float = 10.0

static var _plate: Plate = null
## A smaller plate beside the first, opened from something inside it (a number's working).
static var _sub: Plate = null
static var _layer: CanvasLayer = null
static var _anchor: Control = null
## Controls told to hush until the pointer leaves them (a click closed their plate).
static var _hushed: Dictionary = {}
## How long a finger rests on a thing before its plate comes up, on a touch screen.
const LONG_PRESS: float = 0.42
## A press being held, waiting to become a long-press: its control's id and a token.
static var _press_id: int = 0
static var _press_token: int = 0

## The phone's card (docs/PHONE_UI.md, board sys-touch): what a plate says, on a panel down the
## right side of the screen, its foot a Details button (what a right-click does) and Close.
static var _sheet: PanelContainer = null
static var _sheet_catch: Control = null
static var _sheet_of: Control = null
static var _sheet_sub: PanelContainer = null
## Where the card may stand, from the top and from the foot of the screen, in canvas pixels:
## a screen with a strip and a dock answers it (Vector2(top, foot)); with no answer the card
## runs the height of the screen.
static var bounds: Callable = Callable()
## The card's width, without the phone's own margin at the side (290 points).
const SHEET_WIDTH: float = 580.0

static func attach(control: Control, build: Callable, opts: Dictionary = {}) -> void:
	## Wires a control. `opts`: `tone` (the plate's outline color), `keep` (the plate takes the
	## pointer), `below` (hang it under the control instead of over it), `width` (a fixed
	## plate width). A control wired here has no engine tooltip of its own.
	if control == null:
		return
	control.tooltip_text = ""
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.set_meta("tip_build", build)
	control.set_meta("tip_opts", opts)
	if bool(control.get_meta("tip_wired", false)):
		return
	control.set_meta("tip_wired", true)
	control.mouse_entered.connect(func() -> void: _enter(control))
	control.mouse_exited.connect(func() -> void: _leave(control))
	control.gui_input.connect(func(event: InputEvent) -> void:
		## A press closes the plate until the pointer comes back: what was clicked is now
		## more interesting than what it said. On a touch screen there is no hover: a finger
		## held on the thing brings its plate up, and lifting it puts the plate away.
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _touch():
			if event.pressed:
				control.set_meta("tip_held", false)
				control.set_meta("tip_press_at", event.position)
				_long_press(control)
			else:
				_press_id = 0
				if _anchor == control:
					hide_now()
			return
		## A finger that moves on is scrolling or dragging, not holding.
		if event is InputEventMouseMotion and _press_id == control.get_instance_id() and event.position.distance_to(control.get_meta("tip_press_at", event.position)) > HOLD_SLIP:
			_press_id = 0
			return
		if event is InputEventMouseButton and event.pressed:
			_hushed[control.get_instance_id()] = true
			if _anchor == control:
				hide_now())
	## Keyboard and gamepad: a thing with the focus shows its plate, as one under the pointer does.
	control.focus_entered.connect(func() -> void:
		if not DeepUi.headless() and not DeepUi.phone and control.is_visible_in_tree():
			_show(control))
	control.focus_exited.connect(func() -> void:
		if _anchor == control:
			hide_now())
	control.tree_exiting.connect(func() -> void:
		if _sheet_of == control:
			close_sheet()
		if _anchor == control:
			hide_now())
	control.visibility_changed.connect(func() -> void:
		if _anchor == control and not control.is_visible_in_tree():
			hide_now())

static func adopt_engine_tooltips(tree: SceneTree) -> void:
	## Every plain `tooltip_text` in the game gets the same instant plate: the engine's own
	## tooltip waits a beat however the delay is set. A control is taken over the first time
	## the pointer enters it, so menus and pages need no wiring of their own.
	tree.node_added.connect(func(node: Node) -> void:
		if node is Control and not bool(node.get_meta("tip_wired", false)):
			(node as Control).mouse_entered.connect(func() -> void: _adopt(node as Control), CONNECT_ONE_SHOT))

static func _adopt(control: Control) -> void:
	if not is_instance_valid(control) or control.tooltip_text.is_empty() or bool(control.get_meta("tip_wired", false)):
		return
	attach(control, _adopted_build(control))
	_enter(control)

static func _adopted_build(control: Control) -> Callable:
	## A plate saying the control's own `tooltip_text`, read again each time it comes up.
	var said: String = control.tooltip_text
	return func() -> Control:
		if not control.tooltip_text.is_empty():
			said = control.tooltip_text
			control.tooltip_text = ""
		if said.is_empty():
			return null
		var Plates = load("res://view/ui/plates.gd")
		var box: Control = Plates.plate(280.0)
		DeepUi.effect_text(box, DeepUi.touch_words(said), 12, DeepUi.PAPER)
		return box

## How far a held finger may drift, in canvas pixels, before the hold is a drag instead.
const HOLD_SLIP: float = 14.0

static func hold(control: Control, action: Callable) -> void:
	## On a touch screen a finger held on the control does what a right-click does on a desk:
	## `action`, usually the close look, in place of the plate the hold would otherwise bring
	## up (the close look says everything the plate does, and a phone has no right button).
	## An action that returns false has declined, and the plate comes up instead. A control
	## wired for nothing else is wired here, with a plate for its `tooltip_text` if it has one.
	## The action may read where the finger came down from the control's `tip_press_at` meta.
	if control == null:
		return
	control.set_meta("tip_hold", action)
	if not bool(control.get_meta("tip_wired", false)):
		attach(control, _adopted_build(control))

static func held(control: Control) -> bool:
	## Whether the press on the control now ending (or the last one) was held long enough to
	## become its hold action: the release that follows one is not a click.
	return bool(control.get_meta("tip_held", false))

static func _touch() -> bool:
	return DisplayServer.is_touchscreen_available()

static func _long_press(control: Control) -> void:
	## Starts the wait; the plate comes up if the finger is still down on the thing after it.
	_press_token += 1
	var token: int = _press_token
	var id: int = control.get_instance_id()
	_press_id = id
	if not control.is_inside_tree():
		return
	## A tap often frees the control (its screen closes) before the wait is up. Nothing is
	## called on it until is_instance_valid says it is still there: a release export does not
	## check for freed objects and crashes instead.
	control.get_tree().create_timer(LONG_PRESS).timeout.connect(func() -> void:
		if token != _press_token or _press_id != id or not is_instance_valid(control) or not control.is_visible_in_tree():
			return
		var action: Callable = control.get_meta("tip_hold", Callable())
		if DeepUi.phone:
			_press_id = 0
			if open_sheet(control):
				control.set_meta("tip_held", true)
				return
			if action.is_valid():
				var said: Variant = action.call()
				if not (said is bool and not said):
					control.set_meta("tip_held", true)
			return
		if action.is_valid():
			var answer: Variant = action.call()
			if not (answer is bool and not answer):
				_press_id = 0
				control.set_meta("tip_held", true)
				hide_now()
				return
		_show(control))

static func refresh(control: Control) -> void:
	## A control whose plate is up has something new to say: it is built again in place.
	if _sheet_of == control and _sheet != null and is_instance_valid(_sheet):
		open_sheet(control)
		return
	if _anchor == control and _plate != null and is_instance_valid(_plate):
		_show(control)

static func showing(control: Control) -> bool:
	if _sheet_of == control and _sheet != null and is_instance_valid(_sheet):
		return true
	return _anchor == control and _plate != null and is_instance_valid(_plate) and _plate.visible

# --- the phone's card ----------------------------------------------------------------------------

static func open_sheet(control: Control) -> bool:
	## Brings up the card for `control` (what its plate says), or builds it again in place.
	## False, with nothing shown, when it has nothing to say.
	var build: Callable = control.get_meta("tip_build", Callable())
	var content: Variant = build.call() if build.is_valid() else null
	if not content is Control:
		return false
	close_sheet()
	var layer: CanvasLayer = _layer_for(control)
	## A tap anywhere off the card puts it away (and does nothing else).
	var catch := Control.new()
	catch.name = "SheetCatch"
	catch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catch.mouse_filter = Control.MOUSE_FILTER_STOP
	catch.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_sheet())
	layer.add_child(catch)
	_sheet_catch = catch
	var room: Vector2 = Vector2.ZERO
	if bounds.is_valid():
		var asked: Variant = bounds.call()
		if asked is Vector2:
			room = asked
	var sheet := PanelContainer.new()
	sheet.name = "Sheet"
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = DeepUi.LEDGER_FILL
	style.border_color = DeepUi.ACCENT_DIM
	style.border_width_left = int(DeepUi.pt(1.5))
	style.shadow_color = Color(DeepUi.LEDGER_SHADOW, 0.9)
	style.shadow_size = 0
	style.shadow_offset = Vector2(-DeepUi.pt(3), 0)
	style.content_margin_left = DeepUi.pt(8)
	style.content_margin_right = DeepUi.safe_right + DeepUi.pt(8)
	style.content_margin_top = DeepUi.pt(6)
	style.content_margin_bottom = DeepUi.pt(6) + (DeepUi.safe_bottom if room.y <= 0.0 else 0.0)
	sheet.add_theme_stylebox_override("panel", style)
	sheet.anchor_left = 1.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 0.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = -(SHEET_WIDTH + DeepUi.safe_right)
	sheet.offset_right = 0.0
	sheet.offset_top = room.x
	sheet.offset_bottom = -room.y
	layer.add_child(sheet)
	_sheet = sheet
	_sheet_of = control
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(DeepUi.pt(6)))
	sheet.add_child(column)
	## What it says scrolls when it says more than the card holds (the phone may scroll).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(scroll)
	var said := content as Control
	said.custom_minimum_size.x = 0.0
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(said)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", int(DeepUi.pt(6)))
	column.add_child(foot)
	var action: Callable = control.get_meta("tip_hold", Callable())
	if action.is_valid():
		var details := DeepUi.icon_button(foot, "eye", "Details", func() -> void:
			close_sheet()
			if is_instance_valid(control):
				action.call(), 13, DeepUi.PAPER)
		DeepUi.ledger_button(details, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 9)
		details.custom_minimum_size.y = DeepUi.pt(34)
	var shut := DeepUi.icon_button(foot, "cross_out", "Close", close_sheet, 13, DeepUi.PAPER)
	DeepUi.ledger_button(shut, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 9)
	shut.custom_minimum_size.y = DeepUi.pt(34)
	if not DeepUi.headless():
		sheet.modulate.a = 0.0
		var tween := sheet.create_tween()
		tween.tween_property(sheet, "modulate:a", 1.0, FADE_IN)
	return true

static func close_sheet() -> void:
	## Puts the phone's card away.
	_sheet_of = null
	for node in [_sheet_sub, _sheet, _sheet_catch]:
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
	_sheet = null
	_sheet_catch = null
	_sheet_sub = null

static func sheet_open() -> bool:
	return _sheet != null and is_instance_valid(_sheet)

static func hide_now() -> void:
	_anchor = null
	hide_sub()
	if _plate != null and is_instance_valid(_plate):
		_plate.dismiss(FADE_OUT)
	_plate = null

static func show_sub(from: Control, build: Callable) -> void:
	## Opens the working beside the plate `from` sits in, level with the pointer.
	if DeepUi.phone and sheet_open() and not DeepUi.headless():
		if _sheet_sub != null and is_instance_valid(_sheet_sub):
			_sheet_sub.queue_free()
		var made: Variant = build.call()
		if not made is Control:
			return
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.LEDGER_LINE, 10, 12, 3, 4))
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_sheet.get_parent().add_child(panel)
		panel.add_child(made as Control)
		panel.reset_size()
		panel.position = Vector2(_sheet.global_position.x - panel.size.x - DeepUi.pt(6), from.global_position.y)
		_sheet_sub = panel
		return
	if DeepUi.headless() or _plate == null or not is_instance_valid(_plate):
		return
	hide_sub()
	var content: Variant = build.call()
	if not content is Control:
		return
	_sub = Plate.new()
	_sub.anchor = _plate
	_sub.beside = true
	_sub.gap = 8.0
	_layer_for(from).add_child(_sub)
	_sub.fill(content as Control, DeepUi.LEDGER_LINE, 0.0)
	_sub.appear(FADE_IN)

static func hide_sub() -> void:
	if _sheet_sub != null and is_instance_valid(_sheet_sub):
		_sheet_sub.queue_free()
	_sheet_sub = null
	if _sub != null and is_instance_valid(_sub):
		_sub.dismiss(FADE_OUT)
	_sub = null

static func _enter(control: Control) -> void:
	if DeepUi.headless() or DeepUi.phone or not control.is_visible_in_tree():
		return
	## Nothing shows while something is being dragged: the pointer is busy.
	if control.get_viewport() != null and control.get_viewport().gui_is_dragging():
		return
	_hushed.erase(control.get_instance_id())
	_show(control)

static func _leave(control: Control) -> void:
	_hushed.erase(control.get_instance_id())
	if _anchor != control:
		return
	var opts: Dictionary = control.get_meta("tip_opts", {})
	if bool(opts.get("keep", false)) and _plate != null and is_instance_valid(_plate):
		## The pointer may be on its way onto the plate: the plate decides next frame.
		_plate.leaving = true
		return
	hide_now()

static func _show(control: Control) -> void:
	var build: Callable = control.get_meta("tip_build", Callable())
	if not build.is_valid():
		return
	var content: Variant = build.call()
	if not content is Control:
		## Nothing to say: its own plate goes, and another control's is left alone (a control
		## wired for a hold alone, or whose tooltip is empty, must not take down the plate the
		## pointer is on its way to).
		if _anchor == control:
			hide_now()
		return
	var opts: Dictionary = control.get_meta("tip_opts", {})
	var fresh: bool = _plate == null or not is_instance_valid(_plate) or _anchor != control
	if _plate != null and is_instance_valid(_plate) and _anchor != control:
		_plate.dismiss(0.0)
		_plate = null
	_anchor = control
	if _plate == null or not is_instance_valid(_plate):
		_plate = Plate.new()
		_plate.anchor = control
		_plate.keep = bool(opts.get("keep", false))
		_plate.gap = GAP
		_plate.below = bool(opts.get("below", false))
		_plate.closed.connect(func() -> void:
			if _anchor == control:
				_anchor = null)
		_layer_for(control).add_child(_plate)
	_plate.anchor = control
	_plate.fill(content as Control, Color(opts.get("tone", DeepUi.LEDGER_LINE)), float(opts.get("width", 0.0)))
	if fresh:
		_plate.appear(FADE_IN)
	else:
		_plate.place()

static func _layer_for(control: Control) -> CanvasLayer:
	## One layer over everything, made the first time a plate is wanted and kept.
	if _layer != null and is_instance_valid(_layer) and _layer.is_inside_tree():
		return _layer
	var root: Node = control.get_tree().root if control.is_inside_tree() else null
	if root == null:
		root = Engine.get_main_loop().root
	_layer = CanvasLayer.new()
	_layer.name = "DeepTips"
	_layer.layer = 120
	root.add_child(_layer)
	return _layer
