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
				_long_press(control)
			else:
				_press_id = 0
				if _anchor == control:
					hide_now()
			return
		if event is InputEventMouseButton and event.pressed:
			_hushed[control.get_instance_id()] = true
			if _anchor == control:
				hide_now())
	## Keyboard and gamepad: a thing with the focus shows its plate, as one under the pointer does.
	control.focus_entered.connect(func() -> void:
		if not DeepUi.headless() and control.is_visible_in_tree():
			_show(control))
	control.focus_exited.connect(func() -> void:
		if _anchor == control:
			hide_now())
	control.tree_exiting.connect(func() -> void:
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
	var said: String = control.tooltip_text
	attach(control, func() -> Control:
		if not control.tooltip_text.is_empty():
			said = control.tooltip_text
			control.tooltip_text = ""
		var Plates = load("res://view/ui/plates.gd")
		var box: Control = Plates.plate(280.0)
		DeepUi.effect_text(box, said, 12, DeepUi.PAPER)
		return box)
	_enter(control)

static func _touch() -> bool:
	return DisplayServer.is_touchscreen_available()

static func _long_press(control: Control) -> void:
	## Starts the wait; the plate comes up if the finger is still down on the thing after it.
	_press_token += 1
	var token: int = _press_token
	_press_id = control.get_instance_id()
	if not control.is_inside_tree():
		return
	control.get_tree().create_timer(LONG_PRESS).timeout.connect(func() -> void:
		if token == _press_token and _press_id == control.get_instance_id() and is_instance_valid(control) and control.is_visible_in_tree():
			_show(control))

static func refresh(control: Control) -> void:
	## A control whose plate is up has something new to say: it is built again in place.
	if _anchor == control and _plate != null and is_instance_valid(_plate):
		_show(control)

static func showing(control: Control) -> bool:
	return _anchor == control and _plate != null and is_instance_valid(_plate) and _plate.visible

static func hide_now() -> void:
	_anchor = null
	hide_sub()
	if _plate != null and is_instance_valid(_plate):
		_plate.dismiss(FADE_OUT)
	_plate = null

static func show_sub(from: Control, build: Callable) -> void:
	## Opens the working beside the plate `from` sits in, level with the pointer.
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
	if _sub != null and is_instance_valid(_sub):
		_sub.dismiss(FADE_OUT)
	_sub = null

static func _enter(control: Control) -> void:
	if DeepUi.headless() or not control.is_visible_in_tree():
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
