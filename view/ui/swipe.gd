extends Node
## A sideways flick over a page turns its tabs (docs/PHONE_UI.md, "What a finger does"): the
## finger drawn to the left brings the next tab, to the right the one before. The phone's
## only: the desk has its tabs and keys, and a mouse dragged across a page does nothing. Only
## sideways: nothing turns on a flick up or down (the owner, November 10, 2026).
##
## The watcher reads the pointer in `_input`, before any control, and never takes an event:
## a tap still lands where it fell, a list still scrolls, a stone still drags. It only acts on
## the lift that ends a flick, and not at all when:
## - the pointer went down off the page, or onto something above it (a card, a menu, a sheet);
## - it went down on something that drags sideways itself (a model to turn, a slider, a text
##   field, a sideways scroll) or that asks to be left alone (meta `swipe_off`);
## - a stone or a die is being dragged and dropped (`gui_is_dragging`);
## - it moved more up and down than across (a list's scroll), or too little, or too slowly.

## How far across, in points, before a flick counts.
const LEAST_PT: float = 60.0
## No more than this much up or down for every unit across, anywhere along the way.
const SLOPE: float = 0.55
## A flick, not a slow drag: the most time from press to lift.
const MOST_MS: int = 650

## The page the flick must start on.
var area: Control
## Called with +1 (the next tab) or -1 (the one before), deferred, so it may rebuild the page
## and free this watcher with it.
var turn: Callable

var _down: bool = false
## The frame a flick ended on: the lift that ends it still reaches the control it went down on
## (that is how a list and a button go on working), and a control that acts on a lift asks
## `flicked()` to leave this one alone.
static var _flick_frame: int = -1
var _from: Vector2 = Vector2.ZERO
var _at_ms: int = 0
var _drift: float = 0.0

static func attach(page: Control, on_turn: Callable, holder: Node = null) -> Node:
	## Watches `page` for flicks. The watcher lives under `holder` (the page itself when none
	## is given: a page whose children are cleared on every draw passes its owner).
	var watcher: Node = load("res://view/ui/swipe.gd").new()
	watcher.name = "Swipe"
	watcher.area = page
	watcher.turn = on_turn
	(holder if holder != null else page).add_child(watcher)
	return watcher

static func flicked() -> bool:
	## Whether the lift being handled now ends a flick that turns a tab, not a tap.
	return _flick_frame == Engine.get_process_frames()

static func least() -> float:
	return DeepUi.pt(LEAST_PT)

static func reads(moved: Vector2, drift: float, elapsed_ms: int) -> int:
	## What a press-to-lift movement says: +1 for the next tab, -1 for the one before, 0 for
	## nothing (a tap, a scroll, a slow drag). `drift` is the most it strayed up or down.
	if elapsed_ms > MOST_MS or absf(moved.x) < least():
		return 0
	if maxf(absf(moved.y), drift) > absf(moved.x) * SLOPE:
		return 0
	return 1 if moved.x < 0.0 else -1

func _input(event: InputEvent) -> void:
	if not DeepUi.phone or area == null or not is_instance_valid(area) or not area.is_visible_in_tree() or not turn.is_valid():
		_down = false
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_down = area.get_global_rect().has_point(button.position)
			_from = button.position
			_at_ms = Time.get_ticks_msec()
			_drift = 0.0
			return
		if not _down:
			return
		_down = false
		var way: int = reads(button.position - _from, _drift, Time.get_ticks_msec() - _at_ms)
		if way == 0 or get_viewport().gui_is_dragging() or not _starts_clear():
			return
		_flick_frame = Engine.get_process_frames()
		turn.call_deferred(way)
	elif event is InputEventMouseMotion and _down:
		_drift = maxf(_drift, absf((event as InputEventMouseMotion).position.y - _from.y))

func _starts_clear() -> bool:
	## Whether what the press went down on belongs to the page, with nothing over it, and
	## nothing in its line drags sideways of its own accord. Found by hand at the press's
	## point: on a touch screen the viewport's own idea of what is under the pointer can be
	## the last touch's.
	var under: Control = top_at(get_viewport(), _from)
	if under == null:
		return true
	if not (under == area or area.is_ancestor_of(under)):
		## Something not of the page: fine if it is behind the page (the page's own blank
		## space lets the pointer through to the backdrop), not if it stands over it.
		var mine: int = _layer_of(area)
		var theirs: int = _layer_of(under)
		return theirs < mine or (theirs == mine and not under.is_greater_than(area))
	var node: Node = under
	while node != null and node != area:
		if node is SubViewportContainer or node is Slider or node is ScrollBar or node is LineEdit or node is TextEdit:
			return false
		if node is ScrollContainer and (node as ScrollContainer).get_h_scroll_bar().visible:
			return false
		if bool(node.get_meta("swipe_off", false)):
			return false
		node = node.get_parent()
	return true

static func _layer_of(node: Node) -> int:
	var up: Node = node.get_parent()
	while up != null:
		if up is CanvasLayer:
			return (up as CanvasLayer).layer
		up = up.get_parent()
	return 0

static func top_at(window: Viewport, point: Vector2) -> Control:
	## The control a press at `point` lands on: the highest canvas layer first, and in each
	## the last drawn. Controls that let the pointer through (IGNORE) are looked through.
	var layers: Array = window.find_children("*", "CanvasLayer", true, false).filter(func(layer: CanvasLayer) -> bool:
		return layer.visible and layer.get_viewport() == window)
	layers.sort_custom(func(a: CanvasLayer, b: CanvasLayer) -> bool: return a.layer > b.layer)
	var stacks: Array = []
	for layer in layers:
		if (layer as CanvasLayer).layer > 0:
			stacks.append(layer)
	stacks.append(window)
	for layer in layers:
		if (layer as CanvasLayer).layer <= 0:
			stacks.append(layer)
	for stack in stacks:
		var hit: Control = _hit(stack, point)
		if hit != null:
			return hit
	return null

static func _hit(node: Node, point: Vector2) -> Control:
	for index in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(index)
		if child is CanvasLayer or child is Viewport or child is Node3D:
			continue
		if child is Control:
			var control := child as Control
			if not control.visible:
				continue
			var inside: bool = control.get_global_rect().has_point(point)
			if control.clip_contents and not inside:
				continue
			var deeper: Control = _hit(control, point)
			if deeper != null:
				return deeper
			if inside and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				return control
		elif not child is CanvasItem:
			var found: Control = _hit(child, point)
			if found != null:
				return found
	return null

# --- tabs ----------------------------------------------------------------------------------------

static func tabs(row: Node) -> void:
	## Marks a row of `DeepUi.tab_button`s as the one a flick over its page turns.
	row.set_meta("swipe_tabs", true)

static func turn_tabs(page: Node, way: int) -> bool:
	## Opens the tab next to the open one (`way` +1 the next, -1 the one before) in the first
	## row under `page` marked by `tabs`, as a tap on it would. False when there is none that
	## way, or it cannot be opened (a guest's Daily dig, which the host chooses).
	for row in page.find_children("*", "", true, false):
		if not bool(row.get_meta("swipe_tabs", false)) or not (row is CanvasItem and (row as CanvasItem).is_visible_in_tree()):
			continue
		var buttons: Array = row.find_children("*", "BaseButton", true, false).filter(func(b: Node) -> bool:
			return b.has_meta("tab_on") and (b as CanvasItem).is_visible_in_tree())
		var at: int = -1
		for index in range(buttons.size()):
			if bool(buttons[index].get_meta("tab_on", false)):
				at = index
		var to: int = at + way
		if at < 0 or to < 0 or to >= buttons.size() or (buttons[to] as BaseButton).disabled:
			return false
		## Its own sound comes with it (the kit's buttons play theirs on `pressed`).
		(buttons[to] as BaseButton).pressed.emit()
		return true
	return false
