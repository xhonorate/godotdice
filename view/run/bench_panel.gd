extends Control
## The bench: everything a player carries, laid out to be rearranged. Two tabs: the gems (the
## rail on top, the haul below) and the five dice. Drag a stone onto a socket to set it, or a
## set stone back into the haul to take it out; drag a die onto another slot to change their
## places. Or click anything to put it under the lamp on the right and use the
## buttons there. The bench opens from the strip at any time; while a fight is on it only
## shows, and nothing moves. It never scrolls: a haul too big for the tray is turned a page
## at a time.

const StoneCard = preload("res://view/gems/stone_card.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const HomeScreen = preload("res://view/home/home_screen.gd")
const Inspector = preload("res://view/inspect/inspector.gd")

signal command(cmd: Dictionary)
signal closed

## Three rows of the haul tray.
const HAUL_PAGE: int = 24

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

func open(state: Dictionary, which: String = "") -> void:
	run = state
	if not which.is_empty():
		tab = which
	var was_open: bool = visible
	visible = true
	_render()
	if not was_open:
		DeepAudio.play("ui_open")
		DeepUi.pop_in(_panel, 0.0, 0.96, 0.22)

func refresh(state: Dictionary) -> void:
	run = state
	if visible:
		_render()

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
	DeepUi.clear(_content)
	_targets = []
	var unit: Dictionary = me()
	var room: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	_panel.custom_minimum_size = Vector2(clampf(room.x - 80.0, 720.0, 1240.0), clampf(room.y - 90.0, 480.0, 780.0))
	var head := DeepUi.hbox(_content, 12)
	DeepUi.icon(head, "anvil", 28, DeepUi.ACCENT)
	DeepUi.title(head, "The bench", 28, DeepUi.PAPER)
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
	DeepUi.icon_button(head, "cross_out", "Close", close, 14, DeepUi.MUTED).tooltip_text = "Close the bench (Esc)"
	var note: String = ""
	if not editable():
		note = "A fight is on. You can look, but nothing moves until it is over."
	elif tab == "gems":
		note = "Drag a stone onto a socket to set it, or drag a set stone into the haul to take it out. Click any stone to look at it."
	else:
		note = "Drag a die onto another slot to change their places. Dice are made bigger, smaller or recut at a smithy or a carver, never swapped. Click any die to look at it."
	DeepUi.label(_content, note, 13, DeepUi.MUTED if editable() else DeepUi.BAD.lightened(0.2))
	DeepUi.rule(_content)
	var columns := DeepUi.hbox(_content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := DeepUi.vbox(columns, 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side := DeepUi.vbox(columns, 10)
	side.custom_minimum_size.x = 330
	if unit.is_empty():
		DeepUi.label(left, "Nothing to show.", 14, DeepUi.DIM)
		return
	if tab == "dice":
		_dice_tab(left, unit)
	else:
		_gems_tab(left, unit)
	_lamp(side, unit)

# --- gems --------------------------------------------------------------------------------------

func _gems_tab(parent: VBoxContainer, unit: Dictionary) -> void:
	DeepUi.section(parent, "gem", "Your rail")
	var rail_row := HFlowContainer.new()
	rail_row.add_theme_constant_override("h_separation", 10)
	rail_row.add_theme_constant_override("v_separation", 10)
	parent.add_child(rail_row)
	for index in range(unit.get("rail", []).size()):
		_socket_card(rail_row, unit, index)
	HomeScreen.BirthstoneCard.new(rail_row, str(unit.get("character", "")), 132.0, true)
	var haul: Array = unit.get("haul", [])
	var raw: int = haul.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false))).size()
	var haul_head := DeepUi.hbox(parent, 10)
	DeepUi.section(haul_head, "bag", "Your haul (%d)" % haul.size())
	if raw > 0:
		DeepUi.label(haul_head, "%s raw: appraise at a merchant or a landing before setting" % DeepUi.plural(raw, "stone"), 12, DeepUi.DIM)
	var pages: int = DeepUi.pages(haul.size(), HAUL_PAGE)
	_haul_page = clampi(_haul_page, 0, pages - 1)
	if pages > 1:
		DeepUi.spacer(haul_head)
		DeepUi.pager(haul_head, _haul_page, pages, func(to: int) -> void:
			_haul_page = to
			DeepAudio.play("ui_tap", {"volume": 0.6})
			_render())
	var tray := DeepUi.card(parent, DeepUi.LINE, 12, Color(0.03, 0.035, 0.05, 0.7))
	tray.custom_minimum_size.y = 190
	tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray.tooltip_text = "Drop a set stone here to take it out of its socket"
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	tray.add_child(flow)
	_wire(tray, {}, Callable(), func(data: Dictionary) -> bool:
		return editable() and str(data.get("kind", "")) == "stone" and int(data.get("from_socket", -1)) >= 0,
		func(data: Dictionary) -> void:
			_send({"kind": "unsocket", "index": int(data.from_socket)}, "ui_back"))
	if haul.is_empty():
		DeepUi.label(flow, "Nothing loose. Stones you find wait here until they are set or taken home.", 13, DeepUi.DIM)
	for stone in DeepUi.page_of(haul, _haul_page, HAUL_PAGE):
		_haul_tile(flow, stone)

func _socket_card(parent: Node, unit: Dictionary, index: int) -> void:
	var sockets: Array = unit.get("sockets", [])
	var socket_color: String = str(sockets[index]) if index < sockets.size() else "ANY"
	var stone: Variant = unit.rail[index]
	var set_here: bool = stone is Dictionary
	var tone: Color = DeepUi.color(socket_color) if socket_color != "ANY" else DeepUi.LINE_HI
	var picked: bool = set_here and str(stone.id) == _pick
	var card := DeepUi.card(parent, DeepUi.ACCENT if picked else Color(tone, 0.5), 10, Color(0.05, 0.06, 0.085, 0.92))
	card.custom_minimum_size = Vector2(132, 0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := DeepUi.vbox(card, 4)
	DeepUi.label(box, "Socket %d" % (index + 1), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	var ring := BattleScreen.SocketRing.new(socket_color, not set_here)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	var data: Dictionary = {}
	if set_here:
		var thumb := StoneCard.mini(slot, stone, 62)
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
		DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", stone.skill)), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, "%s · %d ct" % [DeepContent.cut_name(int(stone.get("cut", 0))), int(stone.get("carat", 1))], 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var trigger_row := DeepUi.hbox(box, 0)
		trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
		DiceIcons.build(trigger_row, DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(DeepStone.effective(stone, {}).cut_step)), 14, DeepUi.MUTED)
		if DeepStone.is_locked(stone):
			DeepUi.stat(box, "knot", "knotted", DeepUi.DIM, 11).alignment = BoxContainer.ALIGNMENT_CENTER
		elif editable():
			data = {"kind": "stone", "stone_id": str(stone.id), "from_socket": index}
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		DeepUi.label(box, "Any color" if socket_color == "ANY" else str(DeepContent.color(socket_color).get("name", socket_color)), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var socket_index: int = index
	_wire(card, data, func() -> Control: return Thumbs.GemThumb.new(stone, 64) if set_here else Control.new(),
		func(incoming: Dictionary) -> bool:
			if not editable() or str(incoming.get("kind", "")) != "stone" or int(incoming.get("from_socket", -1)) == socket_index:
				return false
			return DeepDescent.socket_refusal(unit, DeepOddities.find_stone(unit, str(incoming.get("stone_id", ""))), socket_index).is_empty(),
		func(incoming: Dictionary) -> void:
			_send({"kind": "socket", "stone_id": str(incoming.stone_id), "index": socket_index}, "dice_lock"),
		ring)
	if set_here:
		_clickable(card, str(stone.id))

func _haul_tile(parent: Node, stone: Dictionary) -> void:
	var appraised: bool = bool(stone.get("appraised", false))
	var tile := StoneCard.tile(parent, stone, 70)
	var id: String = str(stone.id)
	if id == _pick:
		var style: StyleBoxFlat = (tile.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		style.border_color = DeepUi.ACCENT
		style.set_border_width_all(2)
		tile.add_theme_stylebox_override("panel", style)
	if not appraised:
		tile.modulate = Color(1, 1, 1, 0.75)
		tile.tooltip_text = "Raw: appraise it at a merchant or a landing before it can be set."
	var data: Dictionary = {"kind": "stone", "stone_id": id, "from_socket": - 1} if appraised and editable() else {}
	_wire(tile, data, func() -> Control: return Thumbs.GemThumb.new(stone, 64), Callable(), Callable())
	_clickable(tile, id)

# --- dice --------------------------------------------------------------------------------------

func _dice_tab(parent: VBoxContainer, unit: Dictionary) -> void:
	DeepUi.section(parent, "die", "Your dice")
	var tray_row := HFlowContainer.new()
	tray_row.add_theme_constant_override("h_separation", 10)
	tray_row.add_theme_constant_override("v_separation", 10)
	parent.add_child(tray_row)
	for index in range(unit.get("dice", []).size()):
		_slot_card(tray_row, unit, index)

func _slot_card(parent: Node, unit: Dictionary, index: int) -> void:
	var die: Dictionary = unit.dice[index]
	var id: String = str(die.get("id", ""))
	var card := DeepUi.card(parent, DeepUi.ACCENT if id == _pick else DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.92))
	card.custom_minimum_size = Vector2(150, 0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := DeepUi.vbox(card, 5)
	DeepUi.label(box, "Slot %d" % (index + 1), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var thumb := Thumbs.DieThumb.new(die, 60)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	DeepUi.label(box, DeepDice.describe(die), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	faces_row(box, die, 15)
	var slot_index: int = index
	var data: Dictionary = {"kind": "die", "die_id": id, "from_slot": index} if editable() else {}
	_wire(card, data, func() -> Control: return Thumbs.DieThumb.new(die, 60),
		func(incoming: Dictionary) -> bool:
			return editable() and str(incoming.get("kind", "")) == "die" and str(incoming.get("die_id", "")) != id,
		func(incoming: Dictionary) -> void:
			_send({"kind": "swap_die", "index": slot_index, "die_id": str(incoming.die_id)}, "die_settle"))
	_clickable(card, id)

static func faces_row(parent: Node, die: Dictionary, edge: float) -> HBoxContainer:
	var row := DeepUi.hbox(parent, 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tone: Color = DiceIcons.palette(str(die.get("key", "D6"))).body
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
	if not stone.is_empty():
		_stone_lamp(box, unit, stone)
	elif not die.is_empty():
		_die_lamp(box, unit, die)
	else:
		DeepUi.icon(box, "gem" if tab == "gems" else "die", 40, DeepUi.DIM).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.wrap(box, "Click a %s to look at it here. Right-click anything for its full story." % ("stone" if tab == "gems" else "die"), 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER, 290)

func _stone_lamp(box: VBoxContainer, unit: Dictionary, stone: Dictionary) -> void:
	var id: String = str(stone.id)
	var socket: int = -1
	for i in range(unit.rail.size()):
		if unit.rail[i] is Dictionary and str(unit.rail[i].id) == id:
			socket = i
	## Stood up, picture over words, so the card keeps to the lamp's column.
	StoneCard.build(box, stone, {"size": 84, "text_width": 270, "value": true, "vertical": true})
	if not editable():
		return
	if not bool(stone.get("appraised", false)):
		DeepUi.wrap(box, "Raw. A merchant will appraise it for ore, and a landing will do one for free.", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 290)
	elif socket >= 0:
		DeepUi.stat(box, "check", "Set in socket %d" % (socket + 1), DeepUi.GOOD, 13)
		if not DeepStone.is_locked(stone):
			DeepUi.icon_button(box, "cross_out", "Take it out", func() -> void: _send({"kind": "unsocket", "index": socket}, "ui_back"), 13, DeepUi.MUTED)
	else:
		var fits := HFlowContainer.new()
		fits.add_theme_constant_override("h_separation", 6)
		fits.add_theme_constant_override("v_separation", 6)
		box.add_child(fits)
		var reasons: Dictionary = {}
		for index in range(unit.rail.size()):
			var refusal: String = DeepDescent.socket_refusal(unit, stone, index)
			if refusal.is_empty():
				var target: int = index
				var color: String = str(unit.sockets[index])
				var tint: Color = DeepUi.color(color) if color != "ANY" else DeepUi.PAPER
				DeepUi.icon_button(fits, "gem", "Socket %d" % (index + 1), func() -> void: _send({"kind": "socket", "stone_id": id, "index": target}, "dice_lock"), 12, tint)
			else:
				reasons[refusal] = true
		if fits.get_child_count() == 0:
			DeepUi.wrap(box, "It fits no socket: %s." % ", ".join(reasons.keys()), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 290)
	if socket < 0:
		_give_buttons(box, id)

func _die_lamp(box: VBoxContainer, unit: Dictionary, die: Dictionary) -> void:
	var id: String = str(die.id)
	var thumb := Thumbs.DieThumb.new(die, 96)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(thumb)
	DeepUi.title(box, DeepDice.describe(die), 20, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	faces_row(box, die, 22)
	var definition: Dictionary = DeepContent.die(str(die.get("key", "")))
	if not str(definition.get("text", "")).is_empty():
		DeepUi.wrap(box, str(definition.text), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 290)
	var engraving: String = str(die.get("engraving", ""))
	if not engraving.is_empty():
		for key in DeepContent.section("engravings"):
			var entry: Dictionary = DeepContent.engraving(str(key))
			if str(entry.get("key", "")) == engraving:
				DeepUi.stat(box, "spark", "%s: %s" % [str(entry.get("name", engraving)), str(entry.get("text", ""))], DeepUi.INFO, 12)
	if not editable():
		return
	for i in range(unit.dice.size()):
		if str(unit.dice[i].id) == id:
			DeepUi.stat(box, "check", "Rolling in slot %d" % (i + 1), DeepUi.GOOD, 13)

func _give_buttons(box: VBoxContainer, item_id: String) -> void:
	for other in run.get("players", []):
		if str(other.id) != local_id and bool(other.get("connected", true)):
			var to: String = str(other.id)
			DeepUi.icon_button(box, "party", "Give to %s" % str(other.name), func() -> void: _send({"kind": "give", "to": to, "item_id": item_id}, "ui_confirm"), 13, DeepUi.INFO)

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
