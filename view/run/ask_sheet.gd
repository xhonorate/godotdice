extends Control
## The ask (docs/UI_REDO.md): one block in the middle of the screen whenever a room wants one
## of the party's own things. The question, a big slot for each thing it wants (a stone, a
## die; two for the Hollow), the chosen thing's name on a capsule under its slot, and Never
## mind beside the one button that does the deed. Behind it a scrim dims the room; the dock
## stays lit, and on it the things that would do stay bright while the rest step back (the
## dock's `spotlight`). A click on one of them drops it into the slot at once; dragging it
## onto the slot does the same; the bag opens itself when it holds something that would do.
##
## One form for every room that asks: the oddities, the Hollow, the well (a stone, or pyrite
## on a slider), the smithy and the carver (a die, then a face), the trading table, and a
## merchant's die trade-in. The spec it opens with says what it wants; see `open`.

const Thumbs = preload("res://view/gems/thumbs.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const Plates = preload("res://view/ui/plates.gd")
const Tips = preload("res://view/ui/tips.gd")

signal confirmed(key: String, payload: Dictionary)
signal cancelled
## A slot filled or emptied: whoever lights the dock should light it again.
signal changed

const SLOT_EDGE: float = 110.0
const PICTURE: float = 82.0

## The scrim over the room, placed under the dock by whoever adds this sheet.
var scrim: ColorRect
var spec: Dictionary = {}
## What each slot holds, by the slot's key: an id, or for a `multi` slot an Array of ids.
var picks: Dictionary = {}
## What the extras read: a slider's value, a face's index, an inclusion's key.
var extras: Dictionary = {}
## How much of the bottom of the screen something else holds (the dock and its drawer), so
## the block stays clear of it.
var floor_height: float = 0.0:
	set(value):
		floor_height = value
		_place()
var _block: PanelContainer = null
var _slot_boxes: Dictionary = {}
var _confirm: Button = null
var _extras_box: VBoxContainer = null
var _key: String = ""

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	scrim = ColorRect.new()
	scrim.color = Color(0.01, 0.012, 0.02, 0.6)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.visible = false
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		## A click on the dark closes nothing: the block has its own Never mind. Right-click does.
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			cancel())
	resized.connect(_place)

func is_open() -> bool:
	return visible and not spec.is_empty()

func key() -> String:
	## What this ask is for, so a page drawn again does not open it again.
	return _key

func open(new_spec: Dictionary) -> void:
	## `new_spec`: title, text, glyph, tone, key (what it is for), confirm (the button's words),
	## confirm_glyph, slots: [{key, kind ("stone"/"die"), label, items, refusals, pick, most}]
	## (a slot with `most` over 1 takes up to that many, as the acid bath's racks do), and
	## extras: slider {key, min, max, value, unit}, faces {key, of, blanks, lowering} (a face of
	## the die in slot `of`), inclusions {key, of} (an inclusion of the stone in slot `of`).
	## `build` is a Callable(picks, extras) -> Dictionary that turns the picks into the payload
	## (empty when the ask is not answered yet); without it the picks are the payload.
	var same: bool = str(new_spec.get("key", "")) == _key and is_open()
	spec = new_spec
	_key = str(new_spec.get("key", ""))
	if same:
		## Opened again with the room as it stands now: a pick of something no longer offered goes.
		for slot in spec.get("slots", []):
			var slot_key: String = str(slot.key)
			if not picks.has(slot_key):
				continue
			if picks[slot_key] is Array:
				picks[slot_key] = picks[slot_key].filter(func(id: Variant) -> bool: return _lists(slot, str(id)))
			elif not _lists(slot, str(picks[slot_key])):
				picks.erase(slot_key)
	else:
		picks = {}
		extras = {}
		for slot in spec.get("slots", []):
			var first: Variant = slot.get("pick", null)
			if first != null and str(first) != "":
				picks[str(slot.key)] = first
		var slider: Dictionary = spec.get("slider", {})
		if not slider.is_empty():
			extras[str(slider.key)] = int(slider.get("value", slider.get("min", 0)))
	visible = true
	scrim.visible = true
	_build()
	if not same and not DeepUi.headless():
		DeepUi.pop_in(_block, 0.0, 0.96, 0.18)
	changed.emit()

func close() -> void:
	spec = {}
	_key = ""
	picks = {}
	extras = {}
	visible = false
	scrim.visible = false
	if _block != null and is_instance_valid(_block):
		_block.queue_free()
	_block = null
	_slot_boxes.clear()
	Tips.hide_now()

func cancel() -> void:
	if not is_open():
		return
	DeepAudio.play("ui_back", {"volume": 0.6})
	close()
	cancelled.emit()

func eligible(kind: String) -> Array:
	## The ids of everything of this kind the ask would take now: what any of its slots of
	## that kind lists, less what is refused and what another slot already holds.
	var out: Array = []
	for slot in spec.get("slots", []):
		if str(slot.get("kind", "")) != kind:
			continue
		var refusals: Dictionary = slot.get("refusals", {})
		for item in slot.get("items", []):
			var id: String = str(item.get("id", ""))
			if refusals.has(id) or _held_elsewhere(str(slot.key), id):
				continue
			if not out.has(id):
				out.append(id)
	return out

func wants(kind: String) -> bool:
	return spec.get("slots", []).any(func(s: Dictionary) -> bool: return str(s.get("kind", "")) == kind)

func take(kind: String, id: String) -> bool:
	## Puts a thing into a slot: the first empty slot of its kind, else the first slot of its
	## kind (a new pick for a slot already filled). Refused things are not taken.
	var target: Dictionary = {}
	for slot in spec.get("slots", []):
		if str(slot.get("kind", "")) != kind or not _lists(slot, id) or slot.get("refusals", {}).has(id) or _held_elsewhere(str(slot.key), id):
			continue
		if _empty(slot):
			target = slot
			break
		if target.is_empty():
			target = slot
	if target.is_empty():
		return false
	var slot_key: String = str(target.key)
	if int(target.get("most", 1)) > 1:
		var held: Array = picks.get(slot_key, [])
		if held.has(id):
			return false
		if held.size() >= int(target.most):
			return false
		held = held.duplicate()
		held.append(id)
		picks[slot_key] = held
	else:
		if str(picks.get(slot_key, "")) == id:
			return false
		picks[slot_key] = id
		## A die chosen afresh: the face chosen for the old one means nothing now.
		for extra_key in ["faces", "inclusions"]:
			var extra: Dictionary = spec.get(extra_key, {})
			if not extra.is_empty() and str(extra.get("of", "")) == slot_key:
				extras.erase(str(extra.key))
	DeepAudio.play("dice_lock", {"volume": 0.7})
	_build()
	var box: Control = _slot_boxes.get(slot_key, null)
	if box != null and is_instance_valid(box):
		DeepUi.pulse(box, 1.1, 0.3)
	changed.emit()
	return true

func let_go(slot_key: String, id: String = "") -> void:
	## Empties a slot (or takes one thing out of a multi slot).
	if not picks.has(slot_key):
		return
	if picks[slot_key] is Array:
		var held: Array = picks[slot_key].duplicate()
		held.erase(id)
		picks[slot_key] = held
	else:
		picks.erase(slot_key)
	DeepAudio.play("ui_toggle", {"volume": 0.6})
	_build()
	changed.emit()

func payload() -> Dictionary:
	## The answer, or {} while a slot is still empty.
	for slot in spec.get("slots", []):
		if _empty(slot):
			return {}
	var faces: Dictionary = spec.get("faces", {})
	if not faces.is_empty() and not extras.has(str(faces.key)):
		return {}
	var inclusions: Dictionary = spec.get("inclusions", {})
	if not inclusions.is_empty() and not extras.has(str(inclusions.key)):
		return {}
	var build: Callable = spec.get("build", Callable())
	if build.is_valid():
		return build.call(picks, extras)
	var out: Dictionary = picks.duplicate()
	out.merge(extras, true)
	return out

func _lists(slot: Dictionary, id: String) -> bool:
	return slot.get("items", []).any(func(item: Dictionary) -> bool: return str(item.get("id", "")) == id)

func _held_elsewhere(slot_key: String, id: String) -> bool:
	for other in picks:
		if str(other) == slot_key:
			continue
		var held: Variant = picks[other]
		if (held is Array and (held as Array).has(id)) or str(held) == id:
			return true
	return false

func _empty(slot: Dictionary) -> bool:
	var held: Variant = picks.get(str(slot.key), null)
	if held == null:
		return true
	if held is Array:
		return (held as Array).is_empty()
	return str(held).is_empty()

func _item(slot: Dictionary, id: String) -> Dictionary:
	for item in slot.get("items", []):
		if str(item.get("id", "")) == id:
			return item
	return {}

# --- drawing ------------------------------------------------------------------------------------

func _build() -> void:
	if _block != null and is_instance_valid(_block):
		_block.queue_free()
	_slot_boxes.clear()
	var tone: Color = Color(spec.get("tone", DeepUi.ACCENT))
	_block = PanelContainer.new()
	_block.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, tone, 14, 18, 3, 5))
	_block.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_block)
	var box := DeepUi.vbox(_block, 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := DeepUi.hbox(box, 10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	if not str(spec.get("glyph", "")).is_empty():
		DeepUi.icon(head, str(spec.glyph), 24, tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := DeepUi.title(head, str(spec.get("title", "")), 22, DeepUi.PAPER)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not str(spec.get("text", "")).is_empty():
		var words := DeepUi.wrap(box, str(spec.text), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 440)
		words.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var slots := DeepUi.hbox(box, 22)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	for slot in spec.get("slots", []):
		if int(slot.get("most", 1)) > 1:
			_multi_slot(slots, slot, tone)
		else:
			_slot(slots, slot, tone)
	_extras_box = DeepUi.vbox(box, 8)
	_extras_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_extras(tone)
	if not str(spec.get("blocked", "")).is_empty():
		DeepUi.stat(box, "cross_out", str(spec.blocked), DeepUi.BAD, 13).alignment = BoxContainer.ALIGNMENT_CENTER
	var buttons := DeepUi.hbox(box, 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var never := DeepUi.icon_button(buttons, "cross_out", "Never mind", cancel, 14, DeepUi.MUTED)
	DeepUi.ledger_button(never, DeepUi.SLATE_LOW, DeepUi.LEDGER_LINE, 9, DeepUi.MUTED)
	never.custom_minimum_size = Vector2(0, 40)
	_confirm = DeepUi.primary(buttons, str(spec.get("confirm_glyph", "check")), str(spec.get("confirm", "Do it")), _do, 16, tone)
	DeepUi.ledger_primary(_confirm, tone)
	_confirm.custom_minimum_size = Vector2(180, 40)
	_confirm.disabled = payload().is_empty() or not str(spec.get("blocked", "")).is_empty()
	_block.reset_size()
	_place()

func _do() -> void:
	var answer: Dictionary = payload()
	if answer.is_empty():
		return
	DeepAudio.play("ui_confirm", {"volume": 0.8})
	var was: String = _key
	close()
	confirmed.emit(was, answer)

func _place() -> void:
	## In the middle of the screen, and clear of whatever holds its foot.
	if _block == null or not is_instance_valid(_block):
		return
	var want: Vector2 = _block.get_combined_minimum_size()
	_block.size = want
	## Just above whatever holds the foot of the screen (the dock, and the bag when it is open).
	var room: float = maxf(0.0, size.y - floor_height)
	var y: float = maxf(12.0, room - want.y - 16.0)
	_block.position = Vector2((size.x - want.x) * 0.5, y).round()

func _slot(parent: Control, slot: Dictionary, tone: Color) -> void:
	## One big slot: the ring, the thing in it, and its name on a capsule under it.
	var kind: String = str(slot.get("kind", "stone"))
	var column := DeepUi.vbox(parent, 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	if not str(slot.get("label", "")).is_empty():
		DeepUi.label(column, str(slot.label), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var id: String = str(picks.get(str(slot.key), ""))
	var item: Dictionary = _item(slot, id) if not id.is_empty() else {}
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SLOT_EDGE, SLOT_EDGE)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	column.add_child(holder)
	_slot_boxes[str(slot.key)] = holder
	var ring := SlotRing.new(kind, not item.is_empty(), tone)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(ring)
	if not item.is_empty():
		var picture: Control
		if kind == "die":
			picture = Thumbs.DieThumb.new(item, PICTURE)
		else:
			picture = Thumbs.GemThumb.new(item, PICTURE)
			picture.live_on_hover = false
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, (SLOT_EDGE - PICTURE) * 0.5)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
		var slot_key: String = str(slot.key)
		Tips.attach(holder, func() -> Control:
			if kind == "die":
				return Plates.die(item, {}, {"footer": "Click · take it back out · Right-click · everything"})
			if bool(item.get("appraised", false)):
				return Plates.gem(item, {}, [], {}, [], {"note": "Click · take it back out"})
			return Plates.words(DeepStone.raw_name(item), "%s · %s. Click to take it back out." % [DeepStone.size_name(int(item.get("carat", 1))), str(DeepContent.color(DeepStone.color(item)).get("name", ""))], "raw"))
		holder.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					let_go(slot_key)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					if kind == "die":
						Inspector.die(item)
					else:
						Inspector.stone(item)
				holder.accept_event())
	else:
		var empty := DeepUi.center(holder)
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		DeepUi.icon(empty, "die" if kind == "die" else "gem", 34, Color(tone, 0.45))
		Tips.attach(holder, func() -> Control: return Plates.words("Empty", "Click one of your %s on the dock, or drag it here." % ("dice" if kind == "die" else "stones"), "slot"))
	## Dropped onto the slot: the same as a click on it in the dock.
	var wanted: String = "die_id" if kind == "die" else "stone_id"
	holder.set_drag_forwarding(Callable(), func(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and str(data.get("kind", "")) == kind and eligible(kind).has(str(data.get(wanted, ""))),
		func(_at: Vector2, data: Variant) -> void: take(kind, str(data.get(wanted, ""))))
	var capsule := PanelContainer.new()
	capsule.add_theme_stylebox_override("panel", DeepUi.capsule(capsule, DeepUi.LEDGER_SHADOW, tone if not item.is_empty() else DeepUi.LEDGER_LINE, 2, 16, 2))
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.custom_minimum_size.x = SLOT_EDGE + 24.0
	capsule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(capsule)
	var named: String = _name_of(item, kind) if not item.is_empty() else "Click one below"
	var name_label := DeepUi.label(capsule, named, 12, DeepUi.PAPER if not item.is_empty() else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_font_override("font", DeepUi.bold_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _name_of(item: Dictionary, kind: String) -> String:
	if kind == "die":
		return DeepDice.describe(item)
	if DeepStone.is_geode(item):
		return DeepStone.raw_name(item)
	if not bool(item.get("appraised", false)):
		return "%s · %s" % [DeepStone.raw_name(item), DeepStone.size_name(int(item.get("carat", 1)))]
	return "%s · %d ct" % [DeepUi.skill_name(item), int(item.get("carat", 1))]

func _multi_slot(parent: Control, slot: Dictionary, tone: Color) -> void:
	## Up to `most` things in a row of smaller slots (the acid bath's racks).
	var kind: String = str(slot.get("kind", "stone"))
	var most: int = int(slot.get("most", 3))
	var held: Array = picks.get(str(slot.key), [])
	var column := DeepUi.vbox(parent, 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	if not str(slot.get("label", "")).is_empty():
		DeepUi.label(column, str(slot.label), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var row := DeepUi.hbox(column, 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var slot_key: String = str(slot.key)
	for at in range(most):
		var id: String = str(held[at]) if at < held.size() else ""
		var item: Dictionary = _item(slot, id) if not id.is_empty() else {}
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(84, 84)
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.add_child(holder)
		if at == 0:
			_slot_boxes[slot_key] = holder
		var ring := SlotRing.new(kind, not item.is_empty(), tone)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(ring)
		if not item.is_empty():
			var picture := Thumbs.GemThumb.new(item, 60)
			picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
			picture.live_on_hover = false
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(picture)
			var taken: String = id
			Tips.attach(holder, func() -> Control: return Plates.words(DeepStone.raw_name(item), "Click to take it back out of the rack.", DeepStone.size_name(int(item.get("carat", 1)))))
			holder.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					let_go(slot_key, taken)
					holder.accept_event())
		else:
			var empty := DeepUi.center(holder)
			empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			DeepUi.icon(empty, "drop", 24, Color(tone, 0.45))
		var wanted: String = "die_id" if kind == "die" else "stone_id"
		holder.set_drag_forwarding(Callable(), func(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and str(data.get("kind", "")) == kind and eligible(kind).has(str(data.get(wanted, ""))),
			func(_at: Vector2, data: Variant) -> void: take(kind, str(data.get(wanted, ""))))
	var cost: int = int(slot.get("hp", 0))
	var words: String = "%d in the racks" % held.size() + (" · %d health" % (held.size() * cost) if cost > 0 else "")
	DeepUi.label(column, words, 12, DeepUi.BAD if held.size() > 0 and cost > 0 else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _extras(tone: Color) -> void:
	## A face of the chosen die, an inclusion of the chosen stone, or pyrite on a slider.
	DeepUi.clear(_extras_box)
	var faces: Dictionary = spec.get("faces", {})
	if not faces.is_empty():
		var die_id: String = str(picks.get(str(faces.of), ""))
		var die: Dictionary = {}
		for slot in spec.get("slots", []):
			if str(slot.key) == str(faces.of):
				die = _item(slot, die_id)
		if not die.is_empty():
			DeepUi.label(_extras_box, str(faces.get("label", "Which face?")), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 6)
			row.add_theme_constant_override("v_separation", 6)
			row.alignment = FlowContainer.ALIGNMENT_CENTER
			row.custom_minimum_size.x = 400
			_extras_box.add_child(row)
			var list: Array = die.get("faces", [])
			var chosen: int = int(extras.get(str(faces.key), -1))
			var body: Color = DiceIcons.die_palette(die).body
			for index in range(list.size()):
				var face: Dictionary = list[index]
				var face_kind: String = str(face.get("kind", "plain"))
				if bool(faces.get("lowering", false)) and (face_kind == "blank" or int(face.get("value", 0)) <= 1):
					continue
				if not bool(faces.get("blanks", true)) and face_kind == "blank":
					continue
				var pick := PanelContainer.new()
				pick.add_theme_stylebox_override("panel", DeepUi.ledger(Color(tone, 0.25) if index == chosen else DeepUi.SLATE_LOW, tone if index == chosen else DeepUi.LEDGER_LINE, 6, 4, 2, 0))
				pick.mouse_filter = Control.MOUSE_FILTER_STOP
				pick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				row.add_child(pick)
				var drawn: Control = DiceIcons.face(32.0, int(face.get("value", 0)), body, str(die.get("shape", "D6")), index == chosen, DiceIcons.face_text(int(face.get("value", 0)), face_kind))
				drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pick.add_child(drawn)
				var at: int = index
				pick.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						DeepAudio.play("ui_toggle", {"volume": 0.7})
						extras[str(faces.key)] = at
						_build()
						pick.accept_event())
	var inclusions: Dictionary = spec.get("inclusions", {})
	if not inclusions.is_empty():
		var stone_id: String = str(picks.get(str(inclusions.of), ""))
		var stone: Dictionary = {}
		for slot in spec.get("slots", []):
			if str(slot.key) == str(inclusions.of):
				stone = _item(slot, stone_id)
		var keys: Array = stone.get("inclusions", []) if not stone.is_empty() else []
		if not keys.is_empty():
			DeepUi.label(_extras_box, "Which inclusion?", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			var row := DeepUi.hbox(_extras_box, 6)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			var chosen: String = str(extras.get(str(inclusions.key), ""))
			for key in keys:
				var inclusion: Dictionary = DeepContent.inclusion(str(key))
				var pick := PanelContainer.new()
				pick.add_theme_stylebox_override("panel", DeepUi.ledger(Color(DeepUi.INFO, 0.25) if str(key) == chosen else DeepUi.SLATE_LOW, DeepUi.INFO if str(key) == chosen else DeepUi.LEDGER_LINE, 6, 6, 2, 0))
				pick.mouse_filter = Control.MOUSE_FILTER_STOP
				pick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				pick.tooltip_text = str(inclusion.get("text", ""))
				row.add_child(pick)
				DeepUi.stat(pick, "spark", str(inclusion.get("name", key)), DeepUi.INFO, 12).mouse_filter = Control.MOUSE_FILTER_IGNORE
				var which: String = str(key)
				pick.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						DeepAudio.play("ui_toggle", {"volume": 0.7})
						extras[str(inclusions.key)] = which
						_build()
						pick.accept_event())
	var slider_spec: Dictionary = spec.get("slider", {})
	if not slider_spec.is_empty():
		var least: int = int(slider_spec.get("min", 0))
		var most: int = int(slider_spec.get("max", 0))
		var row := DeepUi.hbox(_extras_box, 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.label(row, str(least), 12, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var slider := HSlider.new()
		slider.min_value = least
		slider.max_value = most
		slider.step = 1
		slider.value = int(extras.get(str(slider_spec.key), least))
		slider.custom_minimum_size = Vector2(240, 26)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.add_child(slider)
		DeepUi.label(row, str(most), 12, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var unit_word: String = str(slider_spec.get("unit", ""))
		var readout := DeepUi.label(row, "%d %s" % [int(slider.value), unit_word], 14, DeepUi.ORE)
		readout.custom_minimum_size.x = 90
		var extra_key: String = str(slider_spec.key)
		slider.value_changed.connect(func(value: float) -> void:
			extras[extra_key] = int(value)
			readout.text = "%d %s" % [int(value), unit_word]
			if _confirm != null and is_instance_valid(_confirm):
				_confirm.disabled = payload().is_empty())
		var top := DeepUi.icon_button(row, "rise", "Max", func() -> void: slider.value = most, 12, DeepUi.ORE)
		DeepUi.ledger_button(top, DeepUi.SLATE_LOW, DeepUi.LEDGER_LINE, 6)

class SlotRing extends Control:
	## The ring a slot is: dashed and dim while empty, whole and lit in the room's color once
	## something is in it. Round for a stone, a square with cut corners for a die.
	var kind: String = "stone"
	var filled: bool = false
	var tone: Color = DeepUi.ACCENT
	func _init(of_kind: String, is_filled: bool, in_tone: Color) -> void:
		kind = of_kind
		filled = is_filled
		tone = in_tone
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var centre := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.47
		draw_circle(centre, radius, Color(tone, 0.12 if filled else 0.05))
		if filled:
			draw_arc(centre, radius, 0.0, TAU, 64, tone, 3.0, true)
			draw_arc(centre, radius * 0.86, 0.0, TAU, 64, Color(tone, 0.3), 1.0, true)
			return
		for arc in range(10):
			var angle: float = TAU * float(arc) / 10.0
			draw_arc(centre, radius, angle, angle + TAU / 16.0, 10, Color(tone, 0.6), 2.5, true)
