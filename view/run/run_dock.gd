extends Control
## What the party carries, always at hand outside a fight: the rail and the five dice along
## the bottom of the screen, where the fight's dock stands when there is a fight, and the bag
## in a drawer that slides up above them.
##
## Everything is moved by dragging. A stone from the bag onto a socket sets it; a set stone
## into the bag takes it out; one of the five dice onto another changes their places (the
## five are the five a player came down with: dice are worked in the mine, never swapped).
## At a stall the stones on the counter drag straight onto a socket or the bag, which buys
## them (and sets them), and a stone from the bag drags onto the lens or the scales in the
## room. A Void gem takes no socket: dropped on one it rides it, in a line of chips under the
## socket's name, and fires right after the socket's own gem; dropped on another rider it
## goes into the line ahead of that one. Right-click anything for the close look. Nothing
## here decides anything: it asks, and the run answers.

const Thumbs = preload("res://view/gems/thumbs.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")

signal command(cmd: Dictionary)
signal drawer_toggled(open: bool)
signal chose(id: String)

const SLOT := 58.0
## A Void gem riding a socket, and how many of them show at this size before a count.
const RIDER := 18.0
const RIDERS_SHOWN := 3
const DOCK_HEIGHT := 150.0
const DRAWER_HEIGHT := 128.0
## How much taller than the dock the chooser stands: enough for a die or a stone at the size
## it is worth looking at, with its name under it.
const CHOOSER_LIFT := 86.0

var local_id: String = ""
var run: Dictionary = {}
var _dock: PanelContainer
var _drawer: PanelContainer
var _open: bool = false
var _key: String = ""
var _targets: Array = []
var _hint: Label = null
## A choice waiting on one of the things the player carries: {kind, items, prompt}. While one
## is up the dock gives way to a tray of those things, large, and nothing else is in the way.
var _offer: Dictionary = {}
var _chooser: PanelContainer = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer = PanelContainer.new()
	_drawer.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.05, 0.06, 0.085, 0.94), Color(DeepUi.ACCENT_DIM, 0.7), 14, 12, 0.5))
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_drawer.offset_left = 120
	_drawer.offset_right = -120
	_drawer.offset_bottom = - DOCK_HEIGHT - 20
	_drawer.offset_top = - DOCK_HEIGHT - 20 - DRAWER_HEIGHT
	_drawer.visible = false
	add_child(_drawer)
	_dock = PanelContainer.new()
	_dock.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.06, 0.075, 0.105, 0.9), Color(DeepUi.LINE_HI, 0.8), 16, 14, 0.55))
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = 16
	_dock.offset_right = -16
	_dock.offset_bottom = -14
	_dock.offset_top = -14 - DOCK_HEIGHT
	add_child(_dock)

func me() -> Dictionary:
	return DeepDescent.player(run, local_id)

func editable() -> bool:
	return DeepDescent.bench_open(run) and not bool(me().get("downed", false))

func is_drawer_open() -> bool:
	return _open

func height() -> float:
	## How much of the bottom of the screen the dock and its drawer take.
	if choosing():
		return DOCK_HEIGHT + 28.0 + CHOOSER_LIFT
	return DOCK_HEIGHT + 28.0 + (DRAWER_HEIGHT + 6.0 if _open else 0.0)

# --- choosing one of your own ------------------------------------------------------------------
##
## Nothing in the mine is worked on through a list of names. When a choice wants one of your
## dice or one of your stones, the dock gives way to those things themselves, drawn large
## over where it stood, and the one to be worked on is clicked. Right-click still opens the
## close look, so a die can be read before it is chosen.

func choosing() -> bool:
	return not _offer.is_empty()

func offer(kind: String, items: Array, prompt: String) -> void:
	## `kind` is "die" or "stone"; `items` are the things themselves, in the order they should
	## stand. Clicking one emits `chose` with its id.
	_offer = {"kind": kind, "items": items, "prompt": prompt}
	_build_chooser()
	## The pages above stop short of whatever holds the bottom of the screen, and the tray is
	## taller than the dock it stands in front of.
	drawer_toggled.emit(_open)

func cancel_offer() -> void:
	if _chooser != null and is_instance_valid(_chooser):
		_chooser.queue_free()
	_chooser = null
	if _offer.is_empty():
		return
	_offer = {}
	_dock.visible = true
	_drawer.visible = _open
	drawer_toggled.emit(_open)

func _build_chooser() -> void:
	if _chooser != null and is_instance_valid(_chooser):
		_chooser.queue_free()
	_dock.visible = false
	_drawer.visible = false
	_chooser = PanelContainer.new()
	_chooser.add_theme_stylebox_override("panel", DeepUi.raised(Color(0.07, 0.085, 0.12, 0.97), Color(DeepUi.ACCENT, 0.7), 16, 14, 0.6))
	_chooser.mouse_filter = Control.MOUSE_FILTER_STOP
	_chooser.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_chooser.offset_left = 16
	_chooser.offset_right = -16
	_chooser.offset_bottom = -14
	_chooser.offset_top = -14 - DOCK_HEIGHT - CHOOSER_LIFT
	add_child(_chooser)
	var column := DeepUi.vbox(_chooser, 8)
	var head := DeepUi.hbox(column, 10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(head, "die" if str(_offer.kind) == "die" else "gem", 20, DeepUi.ACCENT)
	DeepUi.title(head, str(_offer.prompt), 20, DeepUi.PAPER)
	var row := DeepUi.hbox(column, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for item in _offer.items:
		_chooser_tile(row, item, str(_offer.kind))
	if _offer.items.is_empty():
		DeepUi.label(row, "You have nothing this could be done to.", 14, DeepUi.DIM)
	var foot := DeepUi.hbox(column, 10)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon_button(foot, "cross_out", "Never mind", cancel_offer, 13, DeepUi.MUTED)
	if not DeepUi.headless():
		DeepUi.pop_in(_chooser, 0.0, 0.96, 0.18)

func _chooser_tile(parent: Node, item: Dictionary, kind: String) -> void:
	var id: String = str(item.get("id", ""))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", DeepUi.raised(Color(DeepUi.SLATE, 0.92), Color(DeepUi.LINE_HI, 0.8), 12, 8, 0.4))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = (DeepDice.describe(item) if kind == "die" else DeepUi.stone_name(item)) + "\nClick to choose it. Right-click for everything about it."
	parent.add_child(card)
	DeepUi.juice(card, 1.06)
	var box := DeepUi.vbox(card, 4)
	var frame := DeepUi.center(box)
	frame.custom_minimum_size = Vector2(92, 92)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "die":
		var thumb := Thumbs.DieThumb.new(item, 86)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(thumb)
		DeepUi.label(box, DeepDice.describe(item), 12, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER).custom_minimum_size.x = 96
	else:
		var picture := Thumbs.GemThumb.new(item, 84)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(picture)
		var named := DeepUi.label(box, DeepUi.stone_name(item), 12, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		named.custom_minimum_size.x = 120
		named.clip_text = true
	card.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed):
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if kind == "die":
				Inspector.die(item)
			else:
				Inspector.stone(item)
			card.accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			DeepAudio.play("ui_confirm", {"volume": 0.7})
			var chosen: String = id
			cancel_offer()
			chose.emit(chosen)
			card.accept_event())

func set_drawer(open: bool) -> void:
	if open == _open:
		return
	_open = open
	DeepAudio.play("ui_open" if open else "ui_close", {"volume": 0.6})
	_key = ""
	show_run(run)
	if open and not DeepUi.headless():
		DeepUi.pop_in(_drawer, 0.0, 0.97, 0.18)
	drawer_toggled.emit(open)

func toggle_drawer() -> void:
	set_drawer(not _open)

func show_run(state: Dictionary) -> void:
	run = state
	var unit: Dictionary = me()
	## Rebuilt only when something it shows has changed, so a drag is never pulled out from
	## under the pointer by a state that moved for some other reason.
	## A stone or a die keeps its id when it is worked on — a wheel cuts it again, an oven
	## fires it, a smith hammers it — so what each of them shows goes in the key too, or the
	## dock would go on drawing the one that was there before.
	var ids: Array = []
	for stone in unit.get("rail", []):
		ids.append(DeepUi.stone_marks(stone) if stone is Dictionary else "-")
	for line in unit.get("riders", []):
		ids.append("|")
		for rider in line:
			ids.append(DeepUi.stone_marks(rider))
	for group in ["dice", "haul"]:
		ids.append("|")
		for item in unit.get(group, []):
			ids.append(DeepUi.stone_marks(item))
	var key: String = "%s#%s#%s#%d#%d#%d#%s" % [",".join(ids), str(editable()), str(_open), int(unit.get("hp", 0)), int(unit.get("max_hp", 0)), int(unit.get("ore", 0)),
		str(run.get("players", []).map(func(p: Dictionary) -> String: return str(p.get("id", "")) + str(p.get("connected", true))))]
	if key == _key:
		return
	_key = key
	_targets = []
	_build_dock(unit)
	_drawer.visible = _open and not choosing()
	if _open:
		_build_drawer(unit)
		_fit_drawer(unit)
	## Whatever was rebuilt, the tray keeps the bottom of the screen while a choice is open.
	_dock.visible = not choosing()

# --- the dock ----------------------------------------------------------------------------------

func _build_dock(unit: Dictionary) -> void:
	DeepUi.clear(_dock)
	var columns := DeepUi.hbox(_dock, 20)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	## You, and your rail.
	var left := DeepUi.vbox(columns, 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var me_row := DeepUi.hbox(left, 8)
	DeepUi.icon(me_row, "heart", 20, DeepUi.HP, "Your health")
	var bar := DeepUi.bar(me_row, 20.0)
	bar.custom_minimum_size = Vector2(230, 20)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## The count rides in the bar, the way it does in a fight.
	bar.set_values(float(unit.get("hp", 0)) / float(maxi(1, int(unit.get("max_hp", 1)))), "%d / %d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 0))])
	var rail_row := DeepUi.hbox(left, 6)
	var rail: Array = unit.get("rail", [])
	for index in range(rail.size()):
		_socket(rail_row, unit, index)
	var birth: Dictionary = DeepStone.birthstone(str(unit.get("character", "")))
	if not birth.is_empty():
		## Built the way a socket is, slot over name: in a row that stretches what it holds,
		## a bare picture would take the height of its neighbours' captions as well and hang
		## lower than every stone beside it.
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 1)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(SLOT, SLOT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.tooltip_text = "%s, your Birthstone\n%s" % [str(birth.get("name", "")), str(birth.get("text", ""))]
		rail_row.add_child(card)
		card.add_child(holder)
		var ring := BattleScreen.SocketRing.new("BIRTHSTONE", false)
		ring.birth_tint = GemMesh.tint(birth)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(ring)
		var picture := Thumbs.GemThumb.new(birth, SLOT - 12)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
		var birth_name := DeepUi.label(card, str(birth.get("name", "")), 10, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		birth_name.custom_minimum_size.x = SLOT + 6
		birth_name.clip_text = true
		_inspectable(card, func() -> void: Inspector.stone(birth))
	DeepUi.rule(columns, Color(DeepUi.LINE, 0.8)).custom_minimum_size = Vector2(1, 0)
	## Your five dice.
	var middle := DeepUi.vbox(columns, 6)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dice_head := DeepUi.hbox(middle, 8)
	DeepUi.icon(dice_head, "die", 16, DeepUi.ACCENT)
	DeepUi.heading(dice_head, "Your dice", 13)
	var tray := DeepUi.hbox(middle, 8)
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	var dice: Array = unit.get("dice", [])
	for index in range(dice.size()):
		_die_slot(tray, unit, index)
	DeepUi.rule(columns, Color(DeepUi.LINE, 0.8)).custom_minimum_size = Vector2(1, 0)
	## The bag.
	var right := DeepUi.vbox(columns, 8)
	right.custom_minimum_size = Vector2(230, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var haul: int = unit.get("haul", []).size()
	var bag := DeepUi.icon_button(right, "bag", ("Close the bag" if _open else "Open the bag") + "  ·  %d" % haul, toggle_drawer, 14, DeepUi.ACCENT if _open else DeepUi.PAPER)
	bag.tooltip_text = "%s in your bag (B)" % DeepUi.plural(haul, "stone")
	_hint = DeepUi.wrap(right, "", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_LEFT, 226)
	_hint.text = "Drag a stone onto a socket to set it, a die onto a die to change their places." if editable() else "Nothing moves while this lasts."
	var void_about: bool = DeepStone.rider_count(unit) > 0 or unit.get("haul", []).any(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)) and DeepStone.is_slotless(s))
	if editable() and void_about:
		_hint.text = "A Void gem takes no socket: drop it on one to ride beside its gem and fire right after it."

func _socket(parent: Node, unit: Dictionary, index: int) -> void:
	var sockets: Array = unit.get("sockets", [])
	var color: String = str(sockets[index]) if index < sockets.size() else "ANY"
	var stone: Variant = unit.rail[index]
	var set_here: bool = stone is Dictionary
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 1)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(card)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(slot)
	var ring := BattleScreen.SocketRing.new(color, not set_here)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	var data: Dictionary = {}
	if set_here:
		var picture := Thumbs.GemThumb.new(stone, SLOT - 12)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(picture)
		var name_label := DeepUi.label(card, str(DeepStone.skill_of(stone).get("name", "")), 10, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.custom_minimum_size.x = SLOT + 6
		name_label.clip_text = true
		card.tooltip_text = DeepStone.name(stone) + "\n" + DeepStone.text(stone)
		if editable() and not DeepStone.is_locked(stone):
			data = {"kind": "stone", "stone_id": str(stone.id), "from_socket": index, "appraised": true}
			card.mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		DeepUi.label(card, "Any" if color == "ANY" else color.capitalize(), 10, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER).custom_minimum_size.x = SLOT + 6
		card.tooltip_text = "An empty socket: drag any appraised stone onto it. color only matters when the loadout is built at home."
	var riders: Array = DeepStone.riders_of(unit, index)
	if not riders.is_empty():
		_riders_row(card, unit, index, riders)
	var at: int = index
	_wire(card, data, func() -> Control: return Thumbs.GemThumb.new(stone, 60) if set_here else Control.new(),
		func(incoming: Dictionary) -> bool: return _socket_takes(unit, incoming, at),
		func(incoming: Dictionary) -> void: _socket_drop(incoming, at), ring)
	if set_here:
		_inspectable(card, func() -> void:
			var battle: Dictionary = DeepDescent.battle(run)
			var fighter: Dictionary = DeepBattle.player(battle, local_id) if not battle.is_empty() else {}
			var flat: int = DeepStone.flat_index(fighter, at) if not fighter.is_empty() else -1
			Inspector.stone(stone, {"context": DeepBattle.rail_context(battle, fighter, flat)} if flat >= 0 else {}))

func _riders_row(card: Node, unit: Dictionary, socket: int, riders: Array) -> void:
	## The Void gems riding a socket, in a line under its name: each fires after the socket's
	## own gem, in this order. Three show at this size; a count stands for the rest, which
	## the bench lays out in full.
	var row := DeepUi.hbox(card, 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(SLOT + 6, RIDER)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var shown: int = mini(riders.size(), RIDERS_SHOWN)
	for at in range(shown):
		_rider_chip(row, unit, socket, at, riders[at])
	if riders.size() > shown:
		var more := DeepUi.label(row, "+%d" % (riders.size() - shown), 10, DeepUi.INFO)
		more.mouse_filter = Control.MOUSE_FILTER_STOP
		more.tooltip_text = "\n".join(riders.slice(shown).map(func(s: Dictionary) -> String: return DeepStone.name(s))) + "\nOpen the bench (B) to see every rider."

func _rider_chip(parent: Node, unit: Dictionary, socket: int, at: int, stone: Dictionary) -> void:
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(RIDER, RIDER)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = "%s\n%s\nVoid · rides socket %d and fires right after its gem. Fragile: shatters when the run ends; cannot be sold or kept." % [DeepStone.name(stone), DeepStone.text(stone), socket + 1]
	parent.add_child(chip)
	var ring := BattleScreen.SocketRing.new("VOID", false)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chip.add_child(ring)
	var picture := Thumbs.GemThumb.new(stone, RIDER - 4)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(picture)
	var data: Dictionary = {}
	if editable() and not DeepStone.is_locked(stone):
		data = {"kind": "stone", "stone_id": str(stone.id), "from_socket": socket, "rider": at, "appraised": true}
		chip.mouse_default_cursor_shape = Control.CURSOR_DRAG
	## Another Void gem dropped on this one goes into the line ahead of it.
	_wire(chip, data, func() -> Control: return Thumbs.GemThumb.new(stone, 60),
		func(incoming: Dictionary) -> bool: return _rider_takes(unit, incoming, socket, at),
		func(incoming: Dictionary) -> void: _send({"kind": "socket", "stone_id": str(incoming.stone_id), "index": socket, "at": at}, "dice_lock"), ring)
	_inspectable(chip, func() -> void: Inspector.stone(stone))

func _rider_takes(unit: Dictionary, incoming: Dictionary, socket: int, at: int) -> bool:
	if not editable() or str(incoming.get("kind", "")) != "stone":
		return false
	var stone: Dictionary = DeepOddities.find_stone(unit, str(incoming.get("stone_id", "")))
	if stone.is_empty() or not DeepStone.is_slotless(stone):
		return false
	var line: Array = DeepStone.riders_of(unit, socket)
	if at < line.size() and str(line[at].get("id", "")) == str(stone.id):
		return false
	return DeepDescent.socket_refusal(unit, stone, socket).is_empty()

func _socket_takes(unit: Dictionary, incoming: Dictionary, index: int) -> bool:
	if not editable():
		return false
	match str(incoming.get("kind", "")):
		"stone":
			## Its own socket is no move: a set stone stays set, a rider stays in its line.
			if int(incoming.get("from_socket", -1)) == index:
				return false
			return DeepDescent.socket_refusal(unit, DeepOddities.find_stone(unit, str(incoming.get("stone_id", ""))), index).is_empty()
		"shop_item":
			if str(incoming.get("item_kind", "")) != "stone" or int(unit.get("ore", 0)) < int(incoming.get("price", 0)):
				return false
			## Bought, it would be in the bag: would it then fit here?
			var probe: Dictionary = unit.duplicate(true)
			probe.haul.append(incoming.get("stone", {}))
			return DeepDescent.socket_refusal(probe, incoming.get("stone", {}), index).is_empty()
	return false

func _socket_drop(incoming: Dictionary, index: int) -> void:
	match str(incoming.get("kind", "")):
		"stone":
			_send({"kind": "socket", "stone_id": str(incoming.stone_id), "index": index}, "dice_lock")
		"shop_item":
			_send({"kind": "buy", "item_id": str(incoming.item_id)}, "buy")
			_send({"kind": "socket", "stone_id": str(incoming.get("stone", {}).get("id", "")), "index": index}, "dice_lock")

func _die_slot(parent: Node, unit: Dictionary, index: int) -> void:
	var die: Dictionary = unit.dice[index]
	var id: String = str(die.get("id", ""))
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 1)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_DRAG if editable() else Control.CURSOR_ARROW
	card.tooltip_text = DeepDice.describe(die)
	var carved: Dictionary = DeepContent.engraving(str(die.get("engraving", "")))
	if not str(die.get("engraving", "")).is_empty():
		card.tooltip_text += "\n%s: %s" % [str(carved.get("name", die.engraving)), str(carved.get("text", ""))]
	parent.add_child(card)
	var thumb := Thumbs.DieThumb.new(die, SLOT)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(thumb)
	## Only a die's engraving is written under it: its numbers are on its own faces, and the
	## close look has the rest.
	var words := DeepUi.label(card, str(die.get("engraving", "")).replace("_", " ").to_lower(), 10, DeepUi.ACCENT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	words.custom_minimum_size.x = SLOT + 10
	words.clip_text = true
	var at: int = index
	var data: Dictionary = {"kind": "die", "die_id": id, "from_slot": index} if editable() else {}
	_wire(card, data, func() -> Control: return Thumbs.DieThumb.new(die, 60),
		func(incoming: Dictionary) -> bool: return editable() and str(incoming.get("kind", "")) == "die" and str(incoming.get("die_id", "")) != id,
		func(incoming: Dictionary) -> void: _send({"kind": "swap_die", "index": at, "die_id": str(incoming.die_id)}, "die_settle"))
	_inspectable(card, func() -> void: Inspector.die(die))

func _fit_drawer(unit: Dictionary) -> void:
	## The bag is as wide as what is in it and no wider, centred over the dock: an empty one
	## the width of the screen says nothing except that it is empty.
	var wide: float = maxf(640.0, size.x)
	var stones: int = unit.get("haul", []).size()
	var allies: int = run.get("players", []).filter(func(p: Dictionary) -> bool: return str(p.id) != local_id).size()
	var want: float = clampf(260.0 + 64.0 * float(mini(stones, 12)) + (180.0 if allies > 0 else 0.0), wide * 0.3, wide - 240.0)
	var edge: float = (wide - want) * 0.5
	_drawer.offset_left = edge
	_drawer.offset_right = - edge

# --- the drawer --------------------------------------------------------------------------------

func _build_drawer(unit: Dictionary) -> void:
	DeepUi.clear(_drawer)
	var row := DeepUi.hbox(_drawer, 16)
	## Stones.
	var stones := DeepUi.vbox(row, 4)
	stones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var haul: Array = unit.get("haul", [])
	var stone_head := DeepUi.hbox(stones, 8)
	DeepUi.icon(stone_head, "gem", 15, DeepUi.ACCENT)
	DeepUi.heading(stone_head, "Stones (%d)" % haul.size(), 12)
	var raw: int = haul.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false))).size()
	if raw > 0:
		DeepUi.label(stone_head, "%d raw: appraise before setting" % raw, 11, DeepUi.DIM)
	var stone_flow := HFlowContainer.new()
	stone_flow.add_theme_constant_override("h_separation", 6)
	stone_flow.add_theme_constant_override("v_separation", 6)
	stone_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stone_flow.mouse_filter = Control.MOUSE_FILTER_PASS
	stones.add_child(stone_flow)
	if haul.is_empty():
		DeepUi.label(stone_flow, "Nothing loose. Stones you find wait here.", 12, DeepUi.DIM)
	for stone in haul:
		_stone_tile(stone_flow, stone)
	## The stone side of the drawer takes a set stone back, and a stall's goods.
	_wire(stones, {}, Callable(),
		func(incoming: Dictionary) -> bool:
			if not editable():
				return false
			if str(incoming.get("kind", "")) == "stone":
				return int(incoming.get("from_socket", -1)) >= 0
			return str(incoming.get("kind", "")) == "shop_item" and int(me().get("ore", 0)) >= int(incoming.get("price", 0)),
		func(incoming: Dictionary) -> void:
			if str(incoming.get("kind", "")) == "shop_item":
				_send({"kind": "buy", "item_id": str(incoming.item_id)}, "buy")
			else:
				_send({"kind": "unsocket", "index": int(incoming.from_socket), "stone_id": str(incoming.get("stone_id", ""))}, "ui_back"))
	## Allies: drop a loose stone on one to hand it over.
	var others: Array = run.get("players", []).filter(func(p: Dictionary) -> bool: return str(p.id) != local_id and bool(p.get("connected", true)))
	if not others.is_empty():
		DeepUi.rule(row, Color(DeepUi.LINE, 0.8)).custom_minimum_size = Vector2(1, 0)
		var party := DeepUi.vbox(row, 6)
		DeepUi.heading(party, "Give", 12)
		for other in others:
			var to: String = str(other.id)
			var chip := DeepUi.pill(party, "person", str(other.name), DeepUi.INFO, 13, "Drop a loose stone here to give it to %s" % str(other.name))
			chip.mouse_filter = Control.MOUSE_FILTER_STOP
			_wire(chip, {}, Callable(),
				func(incoming: Dictionary) -> bool: return editable() and str(incoming.get("kind", "")) == "stone" and int(incoming.get("from_socket", -1)) < 0,
				func(incoming: Dictionary) -> void: _send({"kind": "give", "to": to, "item_id": str(incoming.get("stone_id", ""))}, "ui_confirm"))

func _stone_tile(parent: Node, stone: Dictionary) -> void:
	var appraised: bool = bool(stone.get("appraised", false))
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(56, 56)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if editable() else Control.CURSOR_ARROW
	tile.tooltip_text = DeepUi.stone_name(stone) + ("" if appraised else "\nRaw: appraise it at a stall or a landing before it can be set.")
	parent.add_child(tile)
	var back := Panel.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.color(DeepStone.color(stone))
	back.add_theme_stylebox_override("panel", DeepUi.flat(Color(0.03, 0.035, 0.05, 0.8), Color(tone, 0.55), 8, 0, 1))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(back)
	var picture := Thumbs.GemThumb.new(stone, 46)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(picture)
	if not appraised:
		tile.modulate = Color(1, 1, 1, 0.8)
	var data: Dictionary = {"kind": "stone", "stone_id": str(stone.id), "from_socket": - 1, "appraised": appraised} if editable() else {}
	_wire(tile, data, func() -> Control: return Thumbs.GemThumb.new(stone, 60), Callable(), Callable())
	_inspectable(tile, func() -> void: Inspector.stone(stone))

# --- wiring --------------------------------------------------------------------------------------

func _send(cmd: Dictionary, sound: String) -> void:
	DeepAudio.play(sound, {"volume": 0.8})
	command.emit(cmd)

func _inspectable(control: Control, look: Callable) -> void:
	## Right-click, or a plain click that did not become a drag, for the close look.
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			look.call()
			control.accept_event())

func _wire(control: Control, data: Dictionary, preview: Callable, accepts: Callable, drop: Callable, ring: Control = null) -> void:
	## Something that can be dragged (when `data` is given) and dropped on (when `accepts` is).
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

func _notification(what: int) -> void:
	## While something is being dragged, the places it could go are lit and the rest dim; a
	## drag from the room opens the drawer, since that is where bought things go.
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and str(data.get("kind", "")) == "shop_item" and not _open:
			set_drawer(true)
		for target in _targets:
			if not is_instance_valid(target.node):
				continue
			var takes: bool = data is Dictionary and bool(target.accepts.call(data))
			target.node.modulate = Color(1.25, 1.2, 1.0) if takes else Color(1, 1, 1, 0.55)
			if target.get("ring") != null and is_instance_valid(target.ring):
				target.ring.set_ready(takes)
	elif what == NOTIFICATION_DRAG_END:
		for target in _targets:
			if is_instance_valid(target.node):
				target.node.modulate = Color.WHITE
			if target.get("ring") != null and is_instance_valid(target.ring):
				target.ring.set_ready(false)
