extends RefCounted
## A row of sockets and a reserve tray, rearranged by dragging.
##
## One board serves every kind of carried thing — gems, dice, relics, and the loadouts on
## the armor stand — because the gestures are the same for all of them: drag from the tray
## into a socket to set it (onto a full socket to replace what is there), drag between
## sockets to reorder, drag out of a socket back to the tray to take it out. A double-click
## does the obvious thing without a drag: a tray item goes into the first open socket, a
## socketed one comes out. Right-click inspects.
##
## The board decides nothing. It reports each gesture through the callables it is given,
## and whoever built it sends the command and rebuilds the screen from the result.
##
## spec:
##   kind, title, hint, reserve_title, empty_reserve   words and the drag type
##   slots: int, socketed: Array, reserve: Array       items are dictionaries with an "id"
##   locked: bool                                      nothing moves; everything inspects
##   edge: float                                       the size of each item's picture
##   art(item, holder: Control, edge)                  puts the picture in the holder
##   caption(item) -> String, tint(item) -> Color, tip(item) -> String
##   pinned(item) -> String                            why it may not leave its socket
##   place(item, index: int, occupant: Dictionary)     index -1: no open socket
##   move(from: int, to: int)                          optional
##   remove(item)                                      optional
##   inspect(item)                                     optional
##   extra(item, box: VBoxContainer)                   optional, under a tray item
##
## Every drag also has a click route: click an item to pick it up, then click the socket, the
## tray item or the tray it should go to. Clicking it again puts it down.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

const TILE_PAD := 12.0

## An item picked up by clicking rather than dragging, per board: the select-then-confirm
## route for anyone not using a mouse drag. A rebuilt board has a new id, so a pick never
## outlives the screen it was made on.
static var _held: Dictionary = {}

static func build(ui: Control, parent: Node, spec: Dictionary) -> VBoxContainer:
	var board: VBoxContainer = ui._vbox(parent, 8)
	var board_id := "%s:%d" % [str(spec.get("kind", "item")), board.get_instance_id()]
	var locked: bool = bool(spec.get("locked", false))
	var head: HBoxContainer = ui._hbox(board, 10)
	ui._label(head, str(spec.get("title", "")), 12, UiKit.GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not str(spec.get("hint", "")).is_empty():
		ui._label(head, str(spec.hint), 12, UiKit.MUTED, true)
	var row: HBoxContainer = ui._hbox(board, 10)
	var socketed: Array = spec.get("socketed", [])
	var slots: int = maxi(int(spec.get("slots", socketed.size())), socketed.size())
	for index in range(slots):
		var item: Dictionary = socketed[index] if index < socketed.size() else {}
		_socket(ui, row, spec, board_id, index, item, locked)
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", UiKit.panel_box(Color("111827"), Color("0b101b"), Color(UiKit.LINE, 0.8), 10, 10, 1.2, 0.0))
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_child(tray)
	var tray_box: VBoxContainer = ui._vbox(tray, 6)
	ui._label(tray_box, str(spec.get("reserve_title", "RESERVE")), 11, UiKit.MUTED)
	var reserve: Array = spec.get("reserve", [])
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	tray_box.add_child(flow)
	if reserve.is_empty():
		ui._label(tray_box, str(spec.get("empty_reserve", "Nothing in reserve.")), 12, UiKit.MUTED, true)
	for index in range(reserve.size()):
		_reserve_tile(ui, flow, spec, board_id, index, reserve[index], socketed, slots, locked)
	# The tray itself takes a socketed item back, dragged there or carried there by click.
	tray.set_drag_forwarding(Callable(),
		func(_at: Vector2, data: Variant) -> bool:
			return _accepts(data, board_id, locked) and _tray_takes(spec, data),
		func(_at: Vector2, data: Variant) -> void:
			spec.remove.call(data.get("item", {})))
	tray.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var carried: Dictionary = _drop_held(board_id)
			if not carried.is_empty() and _tray_takes(spec, carried):
				tray.accept_event()
				spec.remove.call(carried.get("item", {})))
	return board

static func _tray_takes(spec: Dictionary, data: Dictionary) -> bool:
	return str(data.get("from", "")) == "socket" and spec.has("remove") and _pinned(spec, data.get("item", {})).is_empty()

static func _socket(ui: Control, row: Node, spec: Dictionary, board_id: String, index: int, item: Dictionary, locked: bool) -> void:
	var filled := not item.is_empty()
	var accent: Color = Color(spec.tint.call(item)) if filled and spec.has("tint") else UiKit.LINE
	var tile := _tile(ui, row, spec, item, accent, filled, true)
	var number := Label.new()
	number.text = str(index + 1)
	number.add_theme_font_size_override("font_size", 11)
	number.add_theme_color_override("font_color", UiKit.GOLD if filled else UiKit.MUTED)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.position = Vector2(8, 4)
	tile.add_child(number)
	tile.set_meta("focus_tag", "%s_socket_%d" % [str(spec.get("kind", "item")), index])
	var tip := str(spec.tip.call(item)) if filled and spec.has("tip") else "An open socket."
	if not locked:
		tip += "\n\nDrag it, or click it and then click where it should go." if filled else "\n\nDrag a reserve item here, or click one and then click here."
		if filled and spec.has("remove") and _pinned(spec, item).is_empty():
			tip += " Double-click to take it out."
		elif filled and not _pinned(spec, item).is_empty():
			tip += "\n" + _pinned(spec, item)
	if filled and spec.has("inspect"):
		tip += "\nRight-click to inspect."
	tile.tooltip_text = tip
	var socket_count: int = spec.get("socketed", []).size()
	var data := {"board": board_id, "from": "socket", "index": index, "item": item}
	var takes := func(incoming: Dictionary) -> bool:
		return str(incoming.get("from", "")) == "reserve" or (str(incoming.get("from", "")) == "socket" and int(incoming.get("index", -1)) != index and spec.has("move"))
	var land := func(incoming: Dictionary) -> void:
		if str(incoming.get("from", "")) == "reserve":
			spec.place.call(incoming.get("item", {}), index if filled else socket_count, item)
		else:
			spec.move.call(int(incoming.get("index", -1)), mini(index, socket_count - 1))
	tile.set_drag_forwarding(
		func(_at: Vector2) -> Variant:
			if locked or not filled:
				return null
			_drop_held(board_id)
			tile.set_drag_preview(_preview(spec, item))
			tile.modulate = Color(1, 1, 1, 0.35)
			return data,
		func(_at: Vector2, incoming: Variant) -> bool:
			var ok: bool = _accepts(incoming, board_id, locked) and takes.call(incoming)
			_hover(tile, ok)
			return ok,
		func(_at: Vector2, incoming: Variant) -> void:
			_hover(tile, false)
			land.call(incoming))
	tile.mouse_exited.connect(func(): _hover(tile, false); tile.modulate.a = 1.0)
	tile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT and filled and spec.has("inspect"):
				tile.accept_event()
				spec.inspect.call(item)
			elif event.button_index == MOUSE_BUTTON_LEFT and not locked:
				tile.accept_event()
				if event.double_click:
					_drop_held(board_id)
					if filled and spec.has("remove") and _pinned(spec, item).is_empty():
						spec.remove.call(item)
					return
				var carried: Dictionary = _drop_held(board_id)
				if carried.is_empty():
					if filled: _hold(board_id, tile, data)
				elif takes.call(carried):
					land.call(carried)
		elif event.is_action_pressed("ui_accept") and filled and not locked and spec.has("remove") and _pinned(spec, item).is_empty():
			tile.accept_event()
			spec.remove.call(item))

static func _reserve_tile(ui: Control, flow: Node, spec: Dictionary, board_id: String, index: int, item: Dictionary, socketed: Array, slots: int, locked: bool) -> void:
	var accent: Color = Color(spec.tint.call(item)) if spec.has("tint") else UiKit.LINE
	var tile := _tile(ui, flow, spec, item, Color(accent, 0.55), true, false)
	tile.set_meta("focus_tag", "%s_reserve_%d" % [str(spec.get("kind", "item")), index])
	var tip := str(spec.tip.call(item)) if spec.has("tip") else ""
	if not locked:
		tip += "\n\nDrag it onto a socket, or click it and then a socket. Double-click sets it in the first open one."
	if spec.has("inspect"):
		tip += "\nRight-click to inspect."
	tile.tooltip_text = tip.strip_edges()
	var open_index: int = socketed.size() if socketed.size() < slots else -1
	var data := {"board": board_id, "from": "reserve", "index": index, "item": item}
	# A socketed item brought to a tray item trades places with it.
	var land := func(incoming: Dictionary) -> void:
		spec.place.call(item, int(incoming.get("index", -1)), incoming.get("item", {}))
	tile.set_drag_forwarding(
		func(_at: Vector2) -> Variant:
			if locked:
				return null
			_drop_held(board_id)
			tile.set_drag_preview(_preview(spec, item))
			tile.modulate = Color(1, 1, 1, 0.35)
			return data,
		func(_at: Vector2, incoming: Variant) -> bool:
			var ok: bool = _accepts(incoming, board_id, locked) and str(incoming.get("from", "")) == "socket"
			_hover(tile, ok)
			return ok,
		func(_at: Vector2, incoming: Variant) -> void:
			_hover(tile, false)
			land.call(incoming))
	tile.mouse_exited.connect(func(): _hover(tile, false); tile.modulate.a = 1.0)
	tile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT and spec.has("inspect"):
				tile.accept_event()
				spec.inspect.call(item)
			elif event.button_index == MOUSE_BUTTON_LEFT and not locked:
				tile.accept_event()
				if event.double_click:
					_drop_held(board_id)
					spec.place.call(item, open_index, {})
					return
				var carried: Dictionary = _drop_held(board_id)
				if carried.is_empty():
					_hold(board_id, tile, data)
				elif str(carried.get("from", "")) == "socket":
					land.call(carried)
				elif int(carried.get("index", -1)) != index:
					_hold(board_id, tile, data)
		elif event.is_action_pressed("ui_accept") and not locked:
			tile.accept_event()
			spec.place.call(item, open_index, {}))
	if spec.has("extra"):
		spec.extra.call(item, tile.get_child(0))

static func _hold(board_id: String, tile: Control, data: Dictionary) -> void:
	_held[board_id] = {"data": data, "tile": weakref(tile)}
	tile.self_modulate = Color(1.5, 1.35, 0.8, 1.0)

static func _drop_held(board_id: String) -> Dictionary:
	## Puts down whatever this board has picked up and hands it back.
	var held: Dictionary = _held.get(board_id, {})
	_held.erase(board_id)
	if held.is_empty():
		return {}
	var tile: Object = held.tile.get_ref()
	if tile != null and is_instance_valid(tile):
		(tile as Control).self_modulate = Color.WHITE
	return held.data

static func _tile(ui: Control, parent: Node, spec: Dictionary, item: Dictionary, accent: Color, filled: bool, socket: bool) -> PanelContainer:
	var edge: float = float(spec.get("edge", 64))
	var tile := PanelContainer.new()
	tile.focus_mode = Control.FOCUS_ALL
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if filled and not bool(spec.get("locked", false)) else Control.CURSOR_ARROW
	var top: Color = Color("1d2840") if filled else Color("121a2a")
	tile.add_theme_stylebox_override("panel", UiKit.panel_box(top, top.darkened(0.35), accent if filled else Color(UiKit.LINE, 0.6), 10, int(TILE_PAD * 0.5), 1.6 if filled else 1.2, 0.2))
	parent.add_child(tile)
	var box: VBoxContainer = ui._vbox(tile, 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(edge + TILE_PAD, edge + TILE_PAD * 0.5)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	if socket:
		# The setting itself, drawn under whatever sits in it so an empty one still reads as a place.
		holder.draw.connect(func():
			var centre := holder.size * 0.5
			var reach := minf(holder.size.x, holder.size.y) * 0.46
			holder.draw_circle(centre, reach, Color(0, 0, 0, 0.28))
			holder.draw_arc(centre, reach, 0.0, TAU, 32, Color(accent if filled else UiKit.LINE, 0.55 if filled else 0.8), 2.0, true)
			for spoke in 6:
				var angle := TAU * float(spoke) / 6.0 - PI * 0.5
				var tip := centre + Vector2(cos(angle), sin(angle)) * reach
				holder.draw_line(tip, tip - Vector2(cos(angle), sin(angle)) * reach * 0.18, Color(UiKit.GOLD_DIM, 0.8), 3.0, true))
	if filled:
		var art := Control.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(art)
		spec.art.call(item, art, edge)
	var caption: Label = ui._label(box, str(spec.caption.call(item)) if filled and spec.has("caption") else "Open", 11, UiKit.PAPER if filled else UiKit.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.custom_minimum_size.x = edge + TILE_PAD
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile

static func _preview(spec: Dictionary, item: Dictionary) -> Control:
	var edge: float = float(spec.get("edge", 64))
	var anchor := Control.new()
	var art := Control.new()
	art.size = Vector2(edge, edge)
	art.position = -art.size * 0.5
	art.modulate = Color(1, 1, 1, 0.9)
	anchor.add_child(art)
	spec.art.call(item, art, edge)
	return anchor

static func _accepts(data: Variant, board_id: String, locked: bool) -> bool:
	return not locked and data is Dictionary and str(data.get("board", "")) == board_id

static func _pinned(spec: Dictionary, item: Dictionary) -> String:
	return str(spec.pinned.call(item)) if spec.has("pinned") and not item.is_empty() else ""

static func _hover(tile: Control, on: bool) -> void:
	if not is_instance_valid(tile):
		return
	tile.self_modulate = Color(1.35, 1.25, 0.95, 1.0) if on else Color.WHITE
