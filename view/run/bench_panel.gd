extends Control
## The bench: everything a player carries, laid out to be rearranged. Two tabs: the gems (the
## rail on top, the haul below) and the five dice. Drag a stone onto a socket to set it, or a
## set stone back into the haul to take it out; drag a die onto another slot to change their
## places. Or click anything to put it under the lamp on the right and use the
## buttons there. A Void gem takes no socket: dropped on one it rides it, in a line of chips
## under the socket's own gem, and fires right after that gem; dropped on another rider it
## goes into the line ahead of that one. The bench opens from the strip at any time; while a
## fight is on it only shows, and nothing moves. It never scrolls: a haul too big for the
## tray is turned a page at a time.

const StoneCard = preload("res://view/gems/stone_card.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const Plates = preload("res://view/ui/plates.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const Tips = preload("res://view/ui/tips.gd")

signal command(cmd: Dictionary)
signal closed

## Three rows of the haul tray: the first guess at a page, before the tray is measured
## (`_fit_haul_page`), and the gap between its tiles.
const HAUL_PAGE: int = 24
const HAUL_GAP: int = 10
## A Void gem riding a socket, on the socket's card.
const RIDER: float = 26.0

var local_id: String = ""
var run: Dictionary = {}
var tab: String = "gems"
## The id of the stone or die under the lamp.
var _pick: String = ""
var _panel: PanelContainer
var _content: VBoxContainer
## Every drop target on the page, so a drag can light the ones that would take it.
var _targets: Array = []
var _haul_page: int = 0
## How many tiles a page of the haul holds: as many as the tray has room for, measured once it
## is laid out (`_fit_haul_page`).
var _per_page: int = HAUL_PAGE
## The tray's measuring: the latest wait for it, what it was last measured for and how many
## times the page has been drawn again for it (`_fit_haul_page`).
var _fit_token: int = 0
var _fit_seen: String = ""
var _fit_tries: int = 0
## Which part of the haul is showing: "gems", "raw" or "geodes" (see DeepUi.HAUL_TABS).
var _haul_tab: String = "gems"
## What the page was last drawn from (`_shown_key`).
var _key: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 15
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.045, 0.055, 0.08, 0.98), Color(DeepUi.ACCENT_DIM, 0.8), 16, 20, 0.6))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(_panel)
	_content = DeepUi.vbox(_panel, 12)

func is_open() -> bool:
	return visible

func open(state: Dictionary, which: String = "", pick: String = "") -> void:
	## `pick`: a stone to open with picked (a Void rider tapped in the dock's popout, on the
	## phone, comes here to be moved by taps).
	run = state
	if not which.is_empty():
		tab = which
	if not pick.is_empty():
		_pick = pick
	var was_open: bool = visible
	if not was_open:
		## Open on a part of the haul that holds something: an early run often carries only raw stones.
		var everything: Array = me().get("haul", [])
		if DeepUi.haul_of(everything, _haul_tab).is_empty():
			for entry in DeepUi.HAUL_TABS:
				if not DeepUi.haul_of(everything, str(entry[0])).is_empty():
					_haul_tab = str(entry[0])
					_haul_page = 0
					break
	visible = true
	_render()
	if not was_open:
		DeepAudio.play("ui_open")
		DeepUi.pop_in(_panel, 0.0, 0.96, 0.22)

func refresh(state: Dictionary) -> void:
	## Rebuilt only when something it shows has changed: a fight sends a state with every step
	## it plays, and an ally's vote another, and each would pull a drag out from under the pointer.
	run = state
	if visible and _shown_key() != _key:
		_render()

func _shown_key() -> String:
	## Everything the page draws, as one string (the same marks the run dock keys on).
	var unit: Dictionary = me()
	var ids: Array = []
	for stone in unit.get("rail", []):
		ids.append(DeepUi.stone_marks(stone) + ("v" if bool(stone.get("voided", false)) else "") if stone is Dictionary else "-")
	for line in unit.get("riders", []):
		ids.append("|")
		for rider in line:
			ids.append(DeepUi.stone_marks(rider) + ("v" if bool(rider.get("voided", false)) else ""))
	for group in ["dice", "haul"]:
		ids.append("|")
		for item in unit.get(group, []):
			ids.append(DeepUi.stone_marks(item) + ("v" if bool(item.get("voided", false)) else ""))
	var room: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	return "%s#%s#%s#%s#%s#%s#%d#%s#%s#%s" % [",".join(ids), str(unit.get("sockets", [])), str(unit.get("character", "")), tab, _pick, _haul_tab, _haul_page,
		str(editable()), str(unit.is_empty()), str(room)]

func close() -> void:
	if not visible:
		return
	visible = false
	_pick = ""
	DeepAudio.play("ui_back")
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	## Esc closes the close look first, if one is open over the bench, and the bench after.
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not Inspector.is_open():
		close()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	## While something is being dragged, the places it could go are lit and the rest dim.
	if not visible:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		for target in _targets:
			if not is_instance_valid(target.node):
				continue
			var takes: bool = data is Dictionary and bool(target.accepts.call(data))
			target.node.modulate = Color.WHITE if takes else Color(1, 1, 1, 0.4)
			if target.get("ring") != null and is_instance_valid(target.ring):
				target.ring.set_ready(takes)
	elif what == NOTIFICATION_DRAG_END:
		for target in _targets:
			if is_instance_valid(target.node):
				target.node.modulate = Color.WHITE
			if target.get("ring") != null and is_instance_valid(target.ring):
				target.ring.set_ready(false)

func me() -> Dictionary:
	return DeepDescent.player(run, local_id)

func editable() -> bool:
	return DeepDescent.bench_open(run) and not bool(me().get("downed", false))

# --- the page ----------------------------------------------------------------------------------

func _render() -> void:
	_key = _shown_key()
	DeepUi.clear(_content)
	_targets = []
	var unit: Dictionary = me()
	var room: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	## As wide as the gems tab needs on both tabs (every 132 px socket card and the Birthstone
	## card 10 apart, the 20 px column gap, the 330 px lamp side and the panel's 20 px padding
	## each side), so switching tabs never moves the tabs or Close under the pointer.
	var cards: int = unit.get("rail", []).size() + 1
	var gems_wide: float = cards * 132.0 + (cards - 1) * 10.0 + 20.0 + 330.0 + 40.0
	_panel.custom_minimum_size = Vector2(maxf(clampf(room.x - 80.0, 720.0, 1240.0), gems_wide), clampf(room.y - 90.0, 480.0, 780.0))
	if DeepUi.phone:
		## The phone's bench: the whole screen inside its safe edges.
		var edge: float = DeepUi.safe_bottom + DeepUi.pt(4)
		_panel.custom_minimum_size = Vector2(room.x - DeepUi.safe_left - DeepUi.safe_right, room.y - 2.0 * edge)
		_panel.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.045, 0.055, 0.08, 0.98), Color(DeepUi.ACCENT_DIM, 0.8), 16, int(DeepUi.pt(8)), 0.6))
		_content.add_theme_constant_override("separation", int(DeepUi.pt(5)))
	var head := DeepUi.hbox(_content, 12)
	DeepUi.icon(head, "anvil", DeepUi.pt(18) if DeepUi.phone else 28.0, DeepUi.ACCENT)
	DeepUi.title(head, "The bench", 26 if DeepUi.phone else 28, DeepUi.PAPER)
	DeepUi.gap(head, 12)
	var gems := DeepUi.tab_button(head, "gem", "Gems", tab == "gems", func() -> void:
		tab = "gems"
		_render(), 15, unit.get("haul", []).size())
	gems.tooltip_text = "Your rail and the stones in your haul"
	var dice := DeepUi.tab_button(head, "die", "Dice", tab == "dice", func() -> void:
		tab = "dice"
		_render(), 15)
	dice.tooltip_text = "Your five dice"
	DeepUi.spacer(head)
	if DeepUi.phone:
		## What a tap does next, while a stone is picked (the desk's long line is gone).
		var hint: String = _phone_hint(unit)
		if not hint.is_empty():
			DeepUi.label(head, hint, 12, DeepUi.ACCENT_HI)
	var shut := DeepUi.icon_button(head, "cross_out", "Close", close, 14, DeepUi.MUTED)
	shut.tooltip_text = "Close the bench (Esc)"
	if DeepUi.phone:
		shut.custom_minimum_size = Vector2(DeepUi.pt(90), DeepUi.pt(36))
	var note: String = ""
	if not editable():
		note = "A fight is on. You can look, but nothing moves until it is over."
	elif tab == "gems":
		note = "Drag a stone onto a socket to set it, or drag a set stone into the haul to take it out. A Void gem dropped on a socket rides it and fires right after its gem. Click any stone to look at it."
	else:
		note = "Drag a die onto another slot to change their places. A smithy or a carver reworks a die, and a merchant may trade one of theirs for one of yours. Click any die to look at it."
	if not DeepUi.phone or not editable():
		DeepUi.label(_content, note, 13, DeepUi.MUTED if editable() else DeepUi.BAD.lightened(0.2))
	DeepUi.rule(_content)
	var columns := DeepUi.hbox(_content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := DeepUi.vbox(columns, int(DeepUi.pt(5)) if DeepUi.phone else 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side := DeepUi.vbox(columns, 10)
	side.custom_minimum_size.x = 330
	## The phone has no lamp column: a hold reads a stone or a die (board run-bag).
	side.visible = not DeepUi.phone
	if unit.is_empty():
		DeepUi.label(left, "Nothing to show.", 14, DeepUi.DIM)
		return
	if tab == "dice":
		_dice_tab(left, unit)
	else:
		_gems_tab(left, unit)
	if not DeepUi.phone:
		_lamp(side, unit)

func _phone_hint(unit: Dictionary) -> String:
	## The phone's word on the next tap, while a stone is picked.
	if _pick.is_empty() or tab != "gems" or not editable():
		return ""
	if _loose(unit, _pick):
		return "Tap a lit socket to set it"
	if not DeepStone.rider_place(unit, _pick).is_empty():
		return "Tap a socket or a rider to move it, the haul to take it out"
	for stone in unit.get("rail", []):
		if stone is Dictionary and str(stone.id) == _pick and not DeepStone.is_locked(stone):
			return "Tap the haul to take it out"
	return ""

func _rider_moving(unit: Dictionary, socket: int) -> bool:
	## The stone picked is a Void gem riding some other socket, free to move to this one.
	var place: Dictionary = DeepStone.rider_place(unit, _pick)
	return not place.is_empty() and int(place.socket) != socket and not DeepStone.is_locked(DeepOddities.find_stone(unit, _pick))

func _loose(unit: Dictionary, id: String) -> bool:
	## In the haul: neither set nor riding a socket.
	return unit.get("haul", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == id and bool(s.get("appraised", false)) and not DeepStone.is_geode(s))

# --- gems --------------------------------------------------------------------------------------

func _gems_tab(parent: VBoxContainer, unit: Dictionary) -> void:
	DeepUi.section(parent, "gem", "Your rail")
	var rail_row := DeepUi.hbox(parent, 10)
	for index in range(unit.get("rail", []).size()):
		_socket_card(rail_row, unit, index)
	_birth_card(rail_row, unit)
	var everything: Array = unit.get("haul", [])
	var haul: Array = DeepUi.haul_of(everything, _haul_tab)
	var haul_head := DeepUi.hbox(parent, 10)
	DeepUi.section(haul_head, "bag", "Your haul (%d)" % everything.size())
	DeepUi.haul_tabs(haul_head, everything, _haul_tab, func(key: String) -> void:
		_haul_tab = key
		_haul_page = 0
		_render(), 14)
	match _haul_tab:
		"raw":
			DeepUi.label(haul_head, "Appraise at a merchant or a landing before setting", 12, DeepUi.DIM)
		"geodes":
			DeepUi.label(haul_head, "Carried up sealed: the workshop cracks them", 12, DeepUi.DIM)
	var pages: int = DeepUi.pages(haul.size(), _per_page)
	_haul_page = clampi(_haul_page, 0, pages - 1)
	if pages > 1:
		DeepUi.spacer(haul_head)
		DeepUi.pager(haul_head, _haul_page, pages, func(to: int) -> void:
			_haul_page = to
			DeepAudio.play("ui_tap", {"volume": 0.6})
			_render())
	var tray := DeepUi.card(parent, DeepUi.LINE, 12, Color(0.03, 0.035, 0.05, 0.7))
	tray.custom_minimum_size.y = DeepUi.pt(60) if DeepUi.phone else 190.0
	tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray.tooltip_text = "Drop a set stone here to take it out of its socket"
	if DeepUi.phone:
		## A tap on the haul with a set stone picked takes it out.
		tray.gui_input.connect(func(event: InputEvent) -> void:
			if not (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or not editable() or _pick.is_empty():
				return
			var rail: Array = unit.get("rail", [])
			for index in range(rail.size()):
				if rail[index] is Dictionary and str(rail[index].id) == _pick and not DeepStone.is_locked(rail[index]):
					_pick = ""
					tray.accept_event()
					_send({"kind": "unsocket", "index": index}, "ui_back")
					return
			## A Void rider picked: back into the haul.
			var riding: Dictionary = DeepOddities.find_stone(unit, _pick)
			if not DeepStone.rider_place(unit, _pick).is_empty() and not DeepStone.is_locked(riding):
				var id: String = _pick
				_pick = ""
				tray.accept_event()
				_send({"kind": "unsocket", "stone_id": id}, "ui_back"))
	## The tiles stand in a holder that asks for no room of its own, so the tray is as big as the
	## sheet leaves it whatever is on the page, and a page holds as many tiles as the tray does
	## (`_fit_haul_page`), not a fixed count that left rows of it empty.
	var holder := Control.new()
	holder.name = "HaulRoom"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(holder)
	var flow := HFlowContainer.new()
	flow.name = "HaulTiles"
	flow.add_theme_constant_override("h_separation", HAUL_GAP)
	flow.add_theme_constant_override("v_separation", HAUL_GAP)
	flow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(flow)
	if not haul.is_empty():
		## Measured whenever the sheet's layout settles the tray's size (it is sorted a frame
		## or two after the page is built).
		var count: int = haul.size()
		holder.resized.connect(func() -> void: _fit_soon(holder, flow, count))
	_wire(tray, {}, Callable(), func(data: Dictionary) -> bool:
		return editable() and str(data.get("kind", "")) == "stone" and int(data.get("from_socket", -1)) >= 0,
		func(data: Dictionary) -> void:
			_send({"kind": "unsocket", "index": int(data.from_socket), "stone_id": str(data.get("stone_id", ""))}, "ui_back"))
	if haul.is_empty():
		DeepUi.label(flow, {"gems": "No appraised stones in the haul. They wait here until you set them or carry them home.",
			"raw": "No raw stones. Stones you find wait here, in their rock, until they are appraised.",
			"geodes": "No Geodes. A Warden's last hoard and the odd chamber offer them; they come home sealed."}[_haul_tab], 13, DeepUi.DIM)
	for stone in DeepUi.page_of(haul, _haul_page, _per_page):
		_haul_tile(flow, stone)

func _fit_soon(holder: Variant, flow: Variant, count: int) -> void:
	## The tray is measured a frame after its size last changed, never inside the layout pass
	## that changed it (a page drawn again from there would be laid out in the same pass).
	_fit_token += 1
	var token: int = _fit_token
	if not is_inside_tree():
		return
	await get_tree().process_frame
	## The page may have been drawn again (or the bench shut) meanwhile: its tray is gone.
	if token == _fit_token and is_instance_valid(holder) and is_instance_valid(flow) and is_inside_tree():
		_fit_haul_page(holder, flow, count)

func _fit_haul_page(holder: Control, flow: HFlowContainer, count: int) -> void:
	## Once the sheet is laid out: how many tiles the tray holds, rows times columns. A page that
	## holds a different number is drawn again with that many, turned so the first stone shown
	## stays on it. Should the count swing back and forth (a pager that comes and goes changes
	## the tray's height), it settles on the smaller after a few goes, so the page always fits.
	if not is_instance_valid(holder) or not is_instance_valid(flow) or not visible or flow.get_child_count() == 0:
		return
	var tile: Control = flow.get_child(0)
	var step: Vector2 = tile.get_combined_minimum_size() + Vector2(HAUL_GAP, HAUL_GAP)
	var room: Vector2 = holder.size + Vector2(HAUL_GAP, HAUL_GAP)
	if step.x <= HAUL_GAP or step.y <= HAUL_GAP or room.x <= HAUL_GAP or room.y <= HAUL_GAP:
		return
	## At least one whole row, should the tray be shorter than a tile (a phone with a long rail).
	var holds: int = maxi(1, int(floor(room.x / step.x))) * maxi(1, int(floor(room.y / step.y)))
	if holds == _per_page:
		return
	var seen: String = "%s#%d#%s" % [str(get_viewport_rect().size), count, _haul_tab]
	if seen != _fit_seen:
		_fit_seen = seen
		_fit_tries = 0
	_fit_tries += 1
	if _fit_tries > 3:
		if holds > _per_page:
			return
	var first: int = _haul_page * _per_page
	_per_page = holds
	_haul_page = clampi(first / holds, 0, DeepUi.pages(count, holds) - 1)
	_render()

func _birth_card(parent: Node, unit: Dictionary) -> void:
	## The Birthstone at the end of the rail, as the workshop's card shows it, but the one this
	## delver wears this run: a variant of their own, or one the day lent from another delver.
	var card := HomeParts.BirthstoneCard.new(parent, str(unit.get("birthstone_of", unit.get("character", ""))), DeepUi.pt(90) if DeepUi.phone else 132.0, true, str(unit.get("birthstone_key", "")))
	card.name = "BirthCard"
	## What it has come to this run (a Renown's Trophies, a Bloodroot's growth) is said on its tip
	## and on its sheet, which opens knowing who wears it.
	var more: Array = [Plates.birth_count(unit), Plates.birth_opened(unit)].filter(func(line: String) -> bool: return not line.is_empty())
	for thumb in card.find_children("*", "Control", true, false):
		if thumb is Thumbs.GemThumb:
			(thumb as Thumbs.GemThumb).inspect_opts = {"unit": unit}
			if not more.is_empty():
				thumb.tooltip_text = thumb.tooltip_text.replace("\nRight-click for details", "\n" + "\n".join(more) + "\nRight-click for details")

func _socket_card(parent: Node, unit: Dictionary, index: int) -> void:
	var sockets: Array = unit.get("sockets", [])
	var socket_color: String = str(sockets[index]) if index < sockets.size() else DeepContent.SOCKET_RAINBOW
	var stone: Variant = unit.rail[index]
	var set_here: bool = stone is Dictionary
	var tone: Color = DeepUi.socket_tone(socket_color, DeepUi.LINE_HI)
	var picked: bool = set_here and str(stone.id) == _pick
	var card := DeepUi.card(parent, DeepUi.ACCENT if picked else Color(tone, 0.5), 10, Color(0.05, 0.06, 0.085, 0.92))
	card.custom_minimum_size = Vector2(DeepUi.pt(90) if DeepUi.phone else 132.0, 0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := DeepUi.vbox(card, 4)
	DeepUi.label(box, "Socket %d" % (index + 1), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(88, 88) if DeepUi.phone else Vector2(76, 76)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	var ring := BattleScreen.SocketRing.new(socket_color, not set_here)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	if set_here:
		ring.shown = 1 if DeepStone.shows(stone, socket_color) else 0
	var data: Dictionary = {}
	## On the phone the sockets that take the stone picked light up, to be tapped.
	if DeepUi.phone and editable() and (_loose(unit, _pick) or _rider_moving(unit, index)) and DeepDescent.socket_refusal(unit, DeepOddities.find_stone(unit, _pick), index).is_empty():
		ring.set_ready.call_deferred(true)
	if set_here:
		var thumb := StoneCard.mini(slot, stone, 74 if DeepUi.phone else 62)
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
		DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", stone.skill)), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, "%s · %d ct" % [DeepContent.cut_name(int(stone.get("cut", 0))), int(stone.get("carat", 1))], 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var trigger_row := DeepUi.hbox(box, 0)
		trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
		DiceIcons.build(trigger_row, DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(DeepStone.effective(stone, {}).cut_step)), 20, DeepUi.MUTED)
		if DeepStone.is_locked(stone):
			DeepUi.stat(box, "knot", "knotted", DeepUi.DIM, 11).alignment = BoxContainer.ALIGNMENT_CENTER
		elif editable():
			data = {"kind": "stone", "stone_id": str(stone.id), "from_socket": index}
		## An opal beside or behind a gem it cannot touch says so on the bench as in the fight
		## (opals never copy opals): the badge on its ring, with its own plate.
		var warn: Dictionary = RailWarnings.run_blocks(unit).get(index, {})
		if not warn.get("lines", []).is_empty():
			RailWarnings.opal_warn(slot, stone, warn.lines, [], true)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		DeepUi.label(box, DeepContent.socket_name(socket_color), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var riders: Array = DeepStone.riders_of(unit, index)
	if not riders.is_empty():
		## The Void gems riding this socket, in the order they fire after its gem.
		var line := HFlowContainer.new()
		line.alignment = FlowContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("h_separation", 4)
		line.add_theme_constant_override("v_separation", 4)
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		line.tooltip_text = "Riding this socket: Void gems that fire right after its gem, in this order."
		box.add_child(line)
		## The phone's card holds one row of finger-wide discs, so the rail never pushes the
		## haul off the sheet: past two riders it shows the one picked (else the first) and a
		## "+N" that, tapped, picks the next rider of this socket.
		var shown: Array = range(riders.size())
		if DeepUi.phone and riders.size() > 2:
			var picked_at: int = -1
			for at in range(riders.size()):
				if str(riders[at].get("id", "")) == _pick:
					picked_at = at
			shown = [maxi(picked_at, 0)]
		for at in shown:
			_rider_chip(line, unit, index, int(at), riders[int(at)])
		if shown.size() < riders.size():
			_rider_more(line, riders, int(shown[0]))
	var socket_index: int = index
	_wire(card, data, func() -> Control: return Thumbs.GemThumb.new(stone, 64) if set_here else Control.new(),
		func(incoming: Dictionary) -> bool:
			## Its own socket is no move: a set stone stays set, a rider stays in its line.
			if not editable() or str(incoming.get("kind", "")) != "stone" or int(incoming.get("from_socket", -1)) == socket_index:
				return false
			return DeepDescent.socket_refusal(unit, DeepOddities.find_stone(unit, str(incoming.get("stone_id", ""))), socket_index).is_empty(),
		func(incoming: Dictionary) -> void:
			_send({"kind": "socket", "stone_id": str(incoming.stone_id), "index": socket_index}, "dice_lock"),
		ring)
	if DeepUi.phone:
		_phone_socket(card, unit, index, str(stone.id) if set_here else "")
	elif set_here:
		_clickable(card, str(stone.id))

func _phone_socket(card: Control, unit: Dictionary, index: int, set_id: String) -> void:
	## On the phone a stone is set by a tap on it and then on a socket; a tap on a socket
	## with nothing picked picks the stone set in it, as a click does on the desk.
	card.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		card.accept_event()
		## A loose stone picked is set (a Void gem rides); a rider picked rides this socket instead.
		if editable() and (_loose(unit, _pick) or _rider_moving(unit, index)):
			var held: Dictionary = DeepOddities.find_stone(unit, _pick)
			if DeepDescent.socket_refusal(unit, held, index).is_empty():
				_pick = ""
				_send({"kind": "socket", "stone_id": str(held.id), "index": index}, "dice_lock")
			else:
				DeepAudio.play("ui_deny", {"volume": 0.5})
			return
		if set_id.is_empty():
			return
		_pick = "" if _pick == set_id else set_id
		DeepAudio.play("ui_tap", {"volume": 0.6})
		_render.call_deferred())

func _rider_chip(parent: Node, unit: Dictionary, socket: int, at: int, stone: Dictionary) -> void:
	## A Void gem riding this socket, as the fight and the dock draw one: its Hollow picture in a
	## dashed Void disc (VoidMarks). Its plate on hover, the close look on a right-click or a
	## hold; dragged to move it, and another Void gem dropped on it goes into the line ahead. On
	## the phone a tap picks it (then a tap on a socket, a rider or the haul moves it), and a tap
	## on it with another Void gem picked puts that one in the line ahead of it.
	var edge: float = DeepUi.pt(30) if DeepUi.phone else RIDER
	var chip := VoidMarks.VoidDisc.new(edge * 0.5)
	chip.lit = true
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.tooltip_text = "%s\n%s\nVoid · rides socket %d and fires right after its gem. Fragile: shatters when the run ends; cannot be sold or kept." % [DeepStone.name(stone), DeepStone.text(stone), socket + 1]
	parent.add_child(chip)
	chip.hold(VoidMarks.hollow_gem(stone, edge * 0.95), edge * 0.95)
	var id: String = str(stone.id)
	if id == _pick:
		## Picked: a gold ring round the disc.
		var mark := Control.new()
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.draw.connect(func() -> void: mark.draw_arc(mark.size * 0.5, mark.size.x * 0.5 - 1.0, 0.0, TAU, 32, DeepUi.ACCENT, 2.0, true))
		chip.add_child(mark)
	var data: Dictionary = {}
	if editable() and not DeepStone.is_locked(stone):
		data = {"kind": "stone", "stone_id": id, "from_socket": socket, "rider": at}
	var takes := func(incoming: Dictionary) -> bool:
		if not editable() or str(incoming.get("kind", "")) != "stone":
			return false
		var other: Dictionary = DeepOddities.find_stone(unit, str(incoming.get("stone_id", "")))
		if other.is_empty() or not DeepStone.is_slotless(other) or str(other.id) == id or DeepStone.is_locked(other):
			return false
		return DeepDescent.socket_refusal(unit, other, socket).is_empty()
	## Another Void gem dropped on this one goes into the line ahead of it.
	_wire(chip, data, func() -> Control: return VoidMarks.hollow_gem(stone, 64), takes,
		func(incoming: Dictionary) -> void:
			_send({"kind": "socket", "stone_id": str(incoming.stone_id), "index": socket, "at": at}, "dice_lock"))
	## The close look: a right-click on the desk, a finger held on the phone.
	var look := func() -> void: Inspector.stone(stone)
	chip.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			look.call()
			chip.accept_event())
	Tips.hold(chip, func() -> Variant:
		look.call()
		return true)
	if not DeepUi.phone:
		_clickable(chip, id)
		return
	chip.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or Tips.held(chip):
			return
		chip.accept_event()
		## Another Void gem picked (loose, or riding): it goes into the line ahead of this one.
		if not _pick.is_empty() and _pick != id and bool(takes.call({"kind": "stone", "stone_id": _pick})):
			var moving: String = _pick
			_pick = ""
			_send({"kind": "socket", "stone_id": moving, "index": socket, "at": at}, "dice_lock")
			return
		_pick = "" if _pick == id else id
		DeepAudio.play("ui_tap", {"volume": 0.6})
		_render.call_deferred())

func _rider_more(parent: Node, riders: Array, showing: int) -> void:
	## The phone's "+N" after a socket's one shown rider: a tap picks the next rider in the line
	## (round to the first again), so every rider can be reached and moved by taps.
	var more := VoidMarks.CountMark.new(riders.size() - 1, DeepUi.pt(15), int(DeepUi.pt(12)), int(DeepUi.pt(11)))
	more.mouse_filter = Control.MOUSE_FILTER_STOP
	more.tooltip_text = "%d more riding this socket. Tap to pick the next." % (riders.size() - 1)
	parent.add_child(more)
	var next_id: String = str(riders[(showing + 1) % riders.size()].get("id", ""))
	more.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			more.accept_event()
			_pick = next_id
			DeepAudio.play("ui_tap", {"volume": 0.6})
			_render.call_deferred())

func _haul_tile(parent: Node, stone: Dictionary) -> void:
	var appraised: bool = bool(stone.get("appraised", false))
	var tile := StoneCard.tile(parent, stone, 80 if DeepUi.phone else 70)
	var id: String = str(stone.id)
	if id == _pick:
		var style: StyleBoxFlat = (tile.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		style.border_color = DeepUi.ACCENT
		style.set_border_width_all(2)
		tile.add_theme_stylebox_override("panel", style)
	if DeepStone.is_geode(stone):
		tile.tooltip_text = "%s\nSealed: only the workshop can crack it open.\nRight-click for its odds." % DeepStone.raw_name(stone)
	elif not appraised:
		tile.modulate = Color(1, 1, 1, 0.75)
		tile.tooltip_text = "Raw: appraise it at a merchant or a landing before it can be set."
	var data: Dictionary = {"kind": "stone", "stone_id": id, "from_socket": - 1} if appraised and editable() else {}
	_wire(tile, data, func() -> Control: return Thumbs.GemThumb.new(stone, 64), Callable(), Callable())
	_clickable(tile, id)

# --- dice --------------------------------------------------------------------------------------

## The most faces a slot card draws as chips; a bigger die says its range in words instead.
const SLOT_FACES_DRAWN: int = 30

func _dice_tab(parent: VBoxContainer, unit: Dictionary) -> void:
	DeepUi.section(parent, "die", "Your dice")
	## The slots stand the sheet's whole height: each die big enough to see, and its faces big
	## enough to read without a right-click.
	var tray_row := DeepUi.hbox(parent, 10)
	tray_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dice: Array = unit.get("dice", [])
	var tallest: float = 0.0
	for die in dice:
		tallest = maxf(tallest, _faces_height(die))
	for index in range(dice.size()):
		_slot_card(tray_row, unit, index, tallest)
	_face_legend(parent, dice)

func _slot_card(parent: Node, unit: Dictionary, index: int, tallest: float) -> void:
	var die: Dictionary = unit.dice[index]
	var id: String = str(die.get("id", ""))
	var card := DeepUi.card(parent, DeepUi.ACCENT if id == _pick else DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.92))
	card.custom_minimum_size = Vector2(132, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := DeepUi.vbox(card, 6)
	DeepUi.label(box, "Slot %d" % (index + 1), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	## The die and its name stand in the middle of the room the faces leave above them.
	DeepUi.spacer(box, false)
	var thumb := Thumbs.DieThumb.new(die, 96)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	DeepUi.fit_label(box, DeepDice.describe(die), 17, DeepUi.PAPER, 124)
	DeepUi.label(box, _range_words(die), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.spacer(box, false)
	DeepUi.rule(box)
	DeepUi.heading(box, "Faces", 11, DeepUi.DIM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_grid(box, die, tallest)
	var slot_index: int = index
	var data: Dictionary = {"kind": "die", "die_id": id, "from_slot": index} if editable() else {}
	_wire(card, data, func() -> Control: return Thumbs.DieThumb.new(die, 60),
		func(incoming: Dictionary) -> bool:
			return editable() and str(incoming.get("kind", "")) == "die" and str(incoming.get("die_id", "")) != id,
		func(incoming: Dictionary) -> void:
			_send({"kind": "swap_die", "index": slot_index, "die_id": str(incoming.die_id)}, "die_settle"))
	_clickable(card, id)

static func _range_words(die: Dictionary) -> String:
	## "1 to 6 · average 3.5": what the die's faces are worth, read off them.
	var values: Array = die.get("faces", []).map(func(f: Dictionary) -> int: return DeepDice.face_value(f))
	if values.is_empty():
		return ""
	var sum: int = 0
	for value in values:
		sum += int(value)
	var average: float = float(sum) / float(values.size())
	return "%d to %d · average %s" % [int(values.min()), int(values.max()), String.num(snappedf(average, 0.1))]

static func _face_layout(count: int) -> Vector2:
	## How a slot card sets out this many faces: chips across a row, and each chip's edge. Two
	## rows for a d6 or a d8; more and smaller for a bigger die.
	if count <= 8:
		return Vector2(maxi(1, ceili(count / 2.0)), 30.0)
	if count <= 12:
		return Vector2(4, 27.0)
	return Vector2(5, 23.0) if count <= 20 else Vector2(6, 19.0)

static func _faces_height(die: Dictionary) -> float:
	## How tall a slot card's faces stand, so every card's rule and "Faces" sit level.
	var count: int = die.get("faces", []).size()
	if count > SLOT_FACES_DRAWN:
		return 20.0
	var layout: Vector2 = _face_layout(count)
	var rows: int = ceili(float(count) / layout.x)
	return float(rows) * layout.y + float(maxi(0, rows - 1)) * 4.0

static func _face_grid(parent: Node, die: Dictionary, tallest: float = 0.0) -> void:
	## A die's faces as chips in even rows, each tinted by what it is, and in words past what
	## still reads as chips. `tallest` is the slot row's tallest, which every card stands to.
	var faces: Array = die.get("faces", [])
	var rows := DeepUi.vbox(parent, 4)
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.custom_minimum_size.y = tallest
	if faces.size() > SLOT_FACES_DRAWN:
		DeepUi.label(rows, "%d faces" % faces.size(), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var count: int = faces.size()
	var layout: Vector2 = _face_layout(count)
	var across: int = int(layout.x)
	var edge: float = layout.y
	var tone: Color = DiceIcons.die_palette(die).body
	var row: HBoxContainer = null
	for index in range(count):
		if index % maxi(1, across) == 0:
			row = DeepUi.hbox(rows, 4)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
		var f: Dictionary = faces[index]
		var kind: String = str(f.get("kind", "plain"))
		row.add_child(DiceIcons.face(edge, int(f.get("value", 0)), tone if kind == "plain" else DiceIcons.face_kind_tint(kind), str(die.get("shape", "D6")), false, DiceIcons.face_text(int(f.get("value", 0)), kind)))

func _face_legend(parent: VBoxContainer, dice: Array) -> void:
	## One line under the slots: each kind of face these dice have, its chip and what it does.
	var kinds: Array = ["plain"]
	for die in dice:
		for entry in DeepDice.etchings(die):
			if not kinds.has(str(entry.kind)):
				kinds.append(str(entry.kind))
	var band := DeepUi.card(parent, DeepUi.LINE, 10, Color(0.03, 0.035, 0.05, 0.7))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(flow)
	DeepUi.heading(flow, "Face kinds", 11, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plain_tone: Color = DiceIcons.die_palette(dice[0]).body if not dice.is_empty() else DeepUi.PAPER
	for kind in kinds:
		var item := DeepUi.hbox(flow, 6)
		var tint: Color = plain_tone if kind == "plain" else DiceIcons.face_kind_tint(kind)
		var chip := DiceIcons.face(20, 3, tint, "D6", false, DiceIcons.face_text(3, kind))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(chip)
		if kind == "plain":
			DeepUi.label(item, "Plain", 12, DeepUi.PAPER)
			continue
		DeepUi.label(item, DeepDice.etching_name(kind), 12, tint.lightened(0.2)).add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.label(item, str(DeepContent.etching(kind).get("text", "")).trim_suffix("."), 12, DeepUi.MUTED)

static func faces_row(parent: Node, die: Dictionary, edge: float) -> HBoxContainer:
	var row := DeepUi.hbox(parent, 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tone: Color = DiceIcons.die_palette(die).body
	for f in die.get("faces", []):
		row.add_child(DiceIcons.face(edge, int(f.value), tone if str(f.kind) == "plain" else DiceIcons.face_kind_tint(str(f.kind)), str(die.get("shape", "D6")), false, DiceIcons.face_text(int(f.value), str(f.kind))))
	return row

# --- the lamp ----------------------------------------------------------------------------------

func _lamp(parent: VBoxContainer, unit: Dictionary) -> void:
	## Whatever was clicked, looked at properly, with what can be done to it.
	var card := DeepUi.card(parent, DeepUi.LINE, 14)
	var box := DeepUi.vbox(card, 10)
	var stone: Dictionary = DeepOddities.find_stone(unit, _pick) if tab == "gems" else {}
	var die: Dictionary = DeepOddities.find_die(unit, _pick) if tab == "dice" else {}
	## A sealed Geode is in the haul but never found by anything that works on stones.
	var sealed: Array = unit.get("haul", []).filter(func(s: Dictionary) -> bool: return DeepStone.is_geode(s) and str(s.get("id", "")) == _pick) if tab == "gems" else []
	if not sealed.is_empty():
		_geode_lamp(box, sealed[0])
	elif not stone.is_empty():
		_stone_lamp(box, unit, stone)
	elif not die.is_empty():
		_die_lamp(box, unit, die)
	else:
		DeepUi.icon(box, "gem" if tab == "gems" else "die", 40, DeepUi.DIM).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.wrap(box, DeepUi.touch_words("Click a %s to look at it here. Right-click anything for its full story." % ("stone" if tab == "gems" else "die")), 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER, 290)

func _geode_lamp(box: VBoxContainer, geode: Dictionary) -> void:
	## A Geode under the lamp: what kind it is and that it is shut. Nothing can be done to it here.
	StoneCard.build(box, geode, {"size": 84, "text_width": 270, "vertical": true})
	DeepUi.wrap(box, "Nothing down here can open it: carry it up and the workshop's bench cracks it for a stone better than the rock gives. It can be traded at a landing.", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 290)
	DeepUi.icon_button(box, "geode", "Its odds", func() -> void: Inspector.stone(geode), 13, DeepUi.PAPER)

func _stone_lamp(box: VBoxContainer, unit: Dictionary, stone: Dictionary) -> void:
	var id: String = str(stone.id)
	var socket: int = -1
	for i in range(unit.rail.size()):
		if unit.rail[i] is Dictionary and str(unit.rail[i].id) == id:
			socket = i
	var place: Dictionary = DeepStone.rider_place(unit, id)
	## Stood up, picture over words, so the card keeps to the lamp's column.
	StoneCard.build(box, stone, {"size": 84, "text_width": 270, "value": true, "vertical": true})
	if not editable():
		return
	if not bool(stone.get("appraised", false)):
		DeepUi.wrap(box, "Raw. A merchant will appraise it for pyrite, and a landing will do one for free.", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 290)
	elif socket >= 0:
		DeepUi.stat(box, "check", "Set in socket %d" % (socket + 1), DeepUi.GOOD, 13)
		if not DeepStone.is_locked(stone):
			DeepUi.icon_button(box, "cross_out", "Take it out", func() -> void: _send({"kind": "unsocket", "index": socket}, "ui_back"), 13, DeepUi.MUTED)
	elif not place.is_empty():
		## A rider: where it rides, its place in the line, and everywhere else it could ride.
		var host: int = int(place.socket)
		var at: int = int(place.at)
		var line: Array = DeepStone.riders_of(unit, host)
		DeepUi.stat(box, "check", "Riding socket %d · fires right after its gem" % (host + 1), DeepUi.INFO, 13)
		if not DeepStone.is_locked(stone):
			if line.size() > 1:
				var order := DeepUi.hbox(box, 6)
				DeepUi.label(order, "%d of %d in line" % [at + 1, line.size()], 12, DeepUi.MUTED)
				if at > 0:
					DeepUi.icon_button(order, "lift", "Earlier", func() -> void: _send({"kind": "socket", "stone_id": id, "index": host, "at": at - 1}, "dice_lock"), 12, DeepUi.PAPER)
				if at < line.size() - 1:
					DeepUi.icon_button(order, "descend", "Later", func() -> void: _send({"kind": "socket", "stone_id": id, "index": host, "at": at + 2}, "dice_lock"), 12, DeepUi.PAPER)
			_ride_buttons(box, unit, stone, host)
			DeepUi.icon_button(box, "cross_out", "Take it out", func() -> void: _send({"kind": "unsocket", "stone_id": id}, "ui_back"), 13, DeepUi.MUTED)
	elif DeepStone.is_slotless(stone):
		DeepUi.wrap(box, "Void: it takes no socket. It rides one beside whatever is set there and fires right after it.", 12, DeepUi.INFO, HORIZONTAL_ALIGNMENT_LEFT, 290)
		_ride_buttons(box, unit, stone, -1)
	else:
		var fits := HFlowContainer.new()
		fits.add_theme_constant_override("h_separation", 6)
		fits.add_theme_constant_override("v_separation", 6)
		box.add_child(fits)
		var reasons: Dictionary = {}
		for index in range(DeepStone.socket_count(unit)):
			var refusal: String = DeepDescent.socket_refusal(unit, stone, index)
			if refusal.is_empty():
				var target: int = index
				var color: String = str(unit.sockets[index])
				var tint: Color = DeepUi.socket_tone(color, DeepUi.PAPER)
				DeepUi.icon_button(fits, "gem", "Socket %d" % (index + 1), func() -> void: _send({"kind": "socket", "stone_id": id, "index": target}, "dice_lock"), 12, tint)
			else:
				reasons[refusal] = true
		if fits.get_child_count() == 0:
			DeepUi.wrap(box, "It fits no socket: %s." % ", ".join(reasons.keys()), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 290)

func _ride_buttons(box: VBoxContainer, unit: Dictionary, stone: Dictionary, riding: int) -> void:
	## One button per socket a Void gem could ride, the one it rides now left out.
	var id: String = str(stone.id)
	var fits := HFlowContainer.new()
	fits.add_theme_constant_override("h_separation", 6)
	fits.add_theme_constant_override("v_separation", 6)
	box.add_child(fits)
	var reasons: Dictionary = {}
	for index in range(unit.rail.size()):
		if index == riding:
			continue
		var refusal: String = DeepDescent.socket_refusal(unit, stone, index)
		if refusal.is_empty():
			var target: int = index
			DeepUi.icon_button(fits, "gem", "Ride socket %d" % (index + 1), func() -> void: _send({"kind": "socket", "stone_id": id, "index": target}, "dice_lock"), 12, DeepUi.INFO)
		else:
			reasons[refusal] = true
	if fits.get_child_count() == 0 and not reasons.is_empty():
		DeepUi.wrap(box, "It can ride no socket: %s." % ", ".join(reasons.keys()), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 290)

func _die_lamp(box: VBoxContainer, unit: Dictionary, die: Dictionary) -> void:
	var id: String = str(die.id)
	var thumb := Thumbs.DieThumb.new(die, 96)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	DeepUi.title(box, DeepDice.describe(die), 20, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	faces_row(box, die, 22)
	var pattern: String = str(die.get("pattern", ""))
	if not pattern.is_empty():
		DeepUi.stat(box, "pick", "%s: %s" % [DeepDice.pattern_name(pattern), str(DeepContent.pattern(pattern).get("text", ""))], DeepUi.INFO, 12)
	var material: String = str(die.get("material", ""))
	if not material.is_empty():
		DeepUi.stat(box, "spark", "%s: %s" % [DeepDice.material_name(material), str(DeepContent.material(material).get("text", ""))], DiceIcons.die_palette(die).body, 12)
	for entry in DeepDice.etchings(die):
		var kind: String = str(entry.kind)
		DeepUi.stat(box, "spark", "%s: %s" % [DeepDice.etching_name(kind), str(DeepContent.etching(kind).get("text", ""))], DiceIcons.face_kind_tint(kind), 12)
	if not editable():
		return
	for i in range(unit.dice.size()):
		if str(unit.dice[i].id) == id:
			DeepUi.stat(box, "check", "Rolling in slot %d" % (i + 1), DeepUi.GOOD, 13)

# --- wiring ------------------------------------------------------------------------------------

func _send(cmd: Dictionary, sound: String) -> void:
	DeepAudio.play(sound, {"volume": 0.8})
	command.emit(cmd)

func _clickable(control: Control, id: String) -> void:
	## A left click puts the thing under the lamp; a second click takes it away again. It
	## answers the release, so a press that turns into a drag never rebuilds the page under it.
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_pick = "" if _pick == id else id
			DeepAudio.play("ui_tap", {"volume": 0.6})
			## A rider's chip sits on its socket's card: the click is the chip's alone.
			control.accept_event()
			_render.call_deferred())

func _wire(control: Control, data: Dictionary, preview: Callable, accepts: Callable, drop: Callable, ring: Control = null) -> void:
	## Make a control something that can be dragged (when `data` is given) and something that
	## can be dropped on (when `accepts` is given).
	var drag_func: Callable = Callable()
	if not data.is_empty():
		drag_func = func(_at: Vector2) -> Variant:
			var shown: Control = preview.call()
			shown.modulate = Color(1, 1, 1, 0.85)
			control.set_drag_preview(DeepUi.held(shown))
			DeepAudio.play("die_pick", {"gap": 0.0, "volume": 0.7})
			return data
	var can_func: Callable = Callable()
	var drop_func: Callable = Callable()
	if accepts.is_valid():
		can_func = func(_at: Vector2, incoming: Variant) -> bool: return incoming is Dictionary and bool(accepts.call(incoming))
		drop_func = func(_at: Vector2, incoming: Variant) -> void: drop.call(incoming)
		_targets.append({"node": control, "accepts": accepts, "ring": ring})
	control.set_drag_forwarding(drag_func, can_func, drop_func)
