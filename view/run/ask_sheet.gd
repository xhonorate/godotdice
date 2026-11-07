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
## The health the one button would cost, while it is pointed at (0 when it is not).
signal hp_preview(cost: int)

const SLOT_EDGE: float = 110.0
const PICTURE: float = 82.0
## The carver's face picker (`_lay_faces`): the faces' edges, largest first (32 is the face
## the picker always had); the padding round a face in its chip and the gap between chips;
## the faces a row holds before another row is taken, while the sheet has the height for it,
## and the rows past which the rows are made wider instead; and the least room the sheet keeps
## from the screen's sides.
const FACE_EDGES: Array = [32.0, 28.0, 24.0, 20.0]
const FACE_PAD: float = 4.0
const FACE_GAP: float = 6.0
const FACES_PREFERRED: int = 12
const ROWS_PREFERRED: int = 3
const SIDE_ROOM: float = 24.0

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
## How much of the right of the screen the open bag holds (the phone's bag is a panel that far
## across): the block stands in the room left of it.
var side_width: float = 0.0:
	set(value):
		side_width = value
		_place()
var _block: PanelContainer = null
var _slot_boxes: Dictionary = {}
var _confirm: Button = null
var _extras_box: VBoxContainer = null
## The face picker waiting to be laid once the rest of the sheet is built and its room known.
var _faces_job: Dictionary = {}
var _key: String = ""
## The scrim easing in or out.
var _fade: Tween = null

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
	## extras: slider {key, min, max, value, unit}, faces {key, of, blanks, lowering, most} (a face
	## of the die in slot `of`; with `most` over 1, up to that many faces of one die or several,
	## kept in `extras[key]` as [{die_id, face}] while the die in the slot changes), inclusions
	## {key, of} (an inclusion of the stone in slot `of`). `ready`: an ask with nothing to choose
	## (work done to every die) is answered by its button alone, as {"ready": true}.
	## `build` is a Callable(picks, extras) -> Dictionary that turns the picks into the payload
	## (empty when the ask is not answered yet); without it the picks are the payload. `warn` is
	## a Callable(picks) -> String: a warning line under the slots for the current pick ("" for none).
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
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not same and not DeepUi.headless():
		DeepUi.pop_in(_block, 0.0, 0.96, 0.18)
		scrim.modulate.a = 0.0
		_fade = scrim.create_tween()
		_fade.tween_property(scrim, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	else:
		scrim.modulate.a = 1.0
	changed.emit()

func close() -> void:
	hp_preview.emit(0)
	spec = {}
	_key = ""
	picks = {}
	extras = {}
	_slot_boxes.clear()
	Tips.hide_now()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var leaving: Control = _block
	_block = null
	if DeepUi.headless() or not is_inside_tree():
		visible = false
		scrim.visible = false
		if leaving != null and is_instance_valid(leaving):
			leaving.queue_free()
		return
	## Out over a beat: the block shrinks a touch and fades, the scrim lifts with it.
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(scrim, "modulate:a", 0.0, 0.12)
	if leaving != null and is_instance_valid(leaving):
		leaving.pivot_offset = leaving.size * 0.5
		_fade.tween_property(leaving, "modulate:a", 0.0, 0.12)
		_fade.tween_property(leaving, "scale", Vector2.ONE * 0.97, 0.12)
	_fade.chain().tween_callback(func() -> void:
		if leaving != null and is_instance_valid(leaving):
			leaving.queue_free()
		if spec.is_empty():
			visible = false
			scrim.visible = false)

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

func refusal(kind: String, id: String) -> String:
	## Why the ask will not take this thing, as a sentence for its plate, or "" when it would
	## (or when no slot of its kind lists it at all). Refused by every slot that lists it, it
	## says the first slot's reason.
	if not is_open():
		return ""
	var why: String = ""
	for slot in spec.get("slots", []):
		if str(slot.get("kind", "")) != kind or not _lists(slot, id):
			continue
		var refusals: Dictionary = slot.get("refusals", {})
		if not refusals.has(id):
			return ""
		if why.is_empty():
			why = str(refusals[id])
	return sentence(why)

static func sentence(words: String) -> String:
	## The rooms give their reasons as the end of a sentence ("nobody has read it yet"): on a
	## line of its own one starts with a capital and ends with a stop.
	var said: String = words.strip_edges()
	if said.is_empty():
		return ""
	said = said.left(1).to_upper() + said.substr(1)
	return said if said.right(1) in [".", "!", "?"] else said + "."

func _shared_refusal() -> String:
	## The one reason every refused thing has, when they all have the same one: said once
	## under the question, so the dimmed half of the dock is explained before it is pointed at.
	## Left as the rooms word it ("nobody has read it yet"), to follow "Dimmed: ".
	var said: String = ""
	for slot in spec.get("slots", []):
		var refusals: Dictionary = slot.get("refusals", {})
		for id in refusals:
			var why: String = str(refusals[id]).strip_edges()
			if why.is_empty():
				continue
			if not said.is_empty() and why != said:
				return ""
			said = why
	if said.is_empty() or said.right(1) in [".", "!", "?"]:
		return said
	return said + "."

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
		## A die chosen afresh: the face chosen for the old one means nothing now. Faces chosen
		## several at a time stay chosen: they name their own die, and the next die's are added.
		for extra_key in ["faces", "inclusions"]:
			var extra: Dictionary = spec.get(extra_key, {})
			if not extra.is_empty() and str(extra.get("of", "")) == slot_key and not (extra_key == "faces" and face_most() > 1):
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
	if not faces.is_empty() and face_most() > 1 and chosen_faces().is_empty():
		return {}
	var inclusions: Dictionary = spec.get("inclusions", {})
	if not inclusions.is_empty() and not extras.has(str(inclusions.key)):
		return {}
	var build: Callable = spec.get("build", Callable())
	if build.is_valid():
		return build.call(picks, extras)
	var out: Dictionary = picks.duplicate()
	out.merge(extras, true)
	if out.is_empty() and bool(spec.get("ready", false)):
		## Nothing to choose (work done to every die): the button alone is the answer.
		return {"ready": true}
	return out

func face_most() -> int:
	## How many faces the face picker takes: 1, or a three-face service's `most`.
	return maxi(1, int(spec.get("faces", {}).get("most", 1)))

func chosen_faces() -> Array:
	## The faces chosen several at a time, as [{die_id, face}], in the order they were chosen.
	var faces: Dictionary = spec.get("faces", {})
	if faces.is_empty():
		return []
	var held: Variant = extras.get(str(faces.key), [])
	return (held as Array).duplicate() if held is Array else []

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
	_block.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, tone, 14, int(DeepUi.pt(8)) if DeepUi.phone else 18, 3, 5))
	_block.mouse_filter = Control.MOUSE_FILTER_STOP
	if DeepUi.phone:
		_block.custom_minimum_size.x = DeepUi.pt(318)
	add_child(_block)
	var box := DeepUi.vbox(_block, int(DeepUi.pt(5)) if DeepUi.phone else 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := DeepUi.hbox(box, 10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	if not str(spec.get("glyph", "")).is_empty():
		DeepUi.icon(head, str(spec.glyph), DeepUi.glyph_px(15) if DeepUi.phone else 24.0, tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := DeepUi.title(head, str(spec.get("title", "")), 19 if DeepUi.phone else 22, DeepUi.PAPER)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not str(spec.get("text", "")).is_empty():
		var words := DeepUi.wrap(box, str(spec.text), 12 if DeepUi.phone else 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, DeepUi.pt(296) if DeepUi.phone else 440.0)
		words.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	## What is dimmed on the dock, and why, when one reason covers all of it. Each dimmed
	## thing also says its own reason on its plate (run_dock.gd).
	var shared: String = _shared_refusal()
	if not shared.is_empty():
		DeepUi.stat(box, "cross_out", "Dimmed: " + shared, DeepUi.BAD, 13).alignment = BoxContainer.ALIGNMENT_CENTER
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
	## A word on what the current pick costs beyond the room (a Vault stone given up for
	## good); drawn again with every pick, so it follows what is in the slot.
	var warn: Callable = spec.get("warn", Callable())
	if warn.is_valid():
		var said: String = str(warn.call(picks))
		if not said.is_empty():
			DeepUi.stat(box, "chest", said, DeepUi.BAD, 13).alignment = BoxContainer.ALIGNMENT_CENTER
	var buttons := DeepUi.hbox(box, 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var never := DeepUi.icon_button(buttons, "cross_out", "Never mind", cancel, 13 if DeepUi.phone else 14, DeepUi.MUTED)
	DeepUi.ledger_button(never, DeepUi.SLATE_LOW, DeepUi.LEDGER_LINE, 9, DeepUi.MUTED)
	never.custom_minimum_size = Vector2(0, DeepUi.pt(36) if DeepUi.phone else 40.0)
	_confirm = DeepUi.primary(buttons, str(spec.get("confirm_glyph", "check")), str(spec.get("confirm", "Do it")), _do, 14 if DeepUi.phone else 16, tone)
	DeepUi.ledger_primary(_confirm, tone)
	_confirm.custom_minimum_size = Vector2(DeepUi.pt(130), DeepUi.pt(36)) if DeepUi.phone else Vector2(180, 40)
	_confirm.disabled = payload().is_empty() or not str(spec.get("blocked", "")).is_empty()
	_confirm.mouse_entered.connect(func() -> void: hp_preview.emit(_hp_cost()))
	_confirm.mouse_exited.connect(func() -> void: hp_preview.emit(0))
	_confirm.tree_exiting.connect(func() -> void: hp_preview.emit(0))
	_lay_faces()
	_block.reset_size()
	_place()
	## A wrapped line knows how tall it stands only once it is laid out: placed again then, so
	## its foot keeps clear of the dock.
	_block.minimum_size_changed.connect(_place)

func _hp_cost() -> int:
	## What the current picks would take out of the asker: a slot's `hp` for every stone in it.
	var total: int = 0
	for slot in spec.get("slots", []):
		var each: int = int(slot.get("hp", 0))
		if each <= 0:
			continue
		var held: Variant = picks.get(str(slot.key), [])
		total += each * (held.size() if held is Array else (0 if str(held).is_empty() else 1))
	return total

func _do() -> void:
	var answer: Dictionary = payload()
	if answer.is_empty():
		return
	DeepAudio.play("ui_confirm", {"volume": 0.8})
	var was: String = _key
	hp_preview.emit(0)
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
	## Centred in the room the bag leaves, when it is open on the right.
	var across: float = maxf(want.x, size.x - side_width)
	_block.position = Vector2((across - want.x) * 0.5, y).round()

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
	holder.custom_minimum_size = Vector2(DeepUi.pt(52), DeepUi.pt(52)) if DeepUi.phone else Vector2(SLOT_EDGE, SLOT_EDGE)
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
		var look_close := func() -> void:
			if kind == "die":
				Inspector.die(item)
			else:
				Inspector.stone(item)
		holder.gui_input.connect(func(event: InputEvent) -> void:
			if not event is InputEventMouseButton:
				return
			## Let go on the release, so a finger held for the close look does not also take
			## the thing back out.
			if event.button_index == MOUSE_BUTTON_LEFT:
				if not event.pressed and not Tips.held(holder):
					let_go(slot_key)
				holder.accept_event()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				look_close.call()
				holder.accept_event())
		Tips.hold(holder, look_close)
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
			## Laid once the rest of the sheet is built (`_lay_faces`), when the room it has is known.
			var rows := DeepUi.vbox(_extras_box, int(FACE_GAP))
			rows.name = "Faces"
			rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_faces_job = {"holder": rows, "die": die, "faces": faces, "tone": tone}
		if face_most() > 1:
			_face_count(tone)
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

func _face_count(tone: Color) -> void:
	## Faces chosen several at a time: how many of the most, and each one chosen as a chip naming
	## its die and its number (a click puts it back), so a face on another die is not forgotten.
	var faces: Dictionary = spec.get("faces", {})
	var chosen: Array = chosen_faces()
	var most: int = face_most()
	var row := DeepUi.hbox(_extras_box, 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.name = "FaceCount"
	var count := DeepUi.stat(row, "check", "%d of %d chosen" % [chosen.size(), most], tone if not chosen.is_empty() else DeepUi.MUTED, 13)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dice: Array = []
	for slot in spec.get("slots", []):
		if str(slot.key) == str(faces.get("of", "")):
			dice = slot.get("items", [])
	for entry in chosen:
		var die: Dictionary = {}
		for item in dice:
			if str(item.get("id", "")) == str(entry.get("die_id", "")):
				die = item
		var list: Array = die.get("faces", [])
		var at: int = int(entry.get("face", -1))
		if at < 0 or at >= list.size():
			continue
		var face: Dictionary = list[at]
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", DeepUi.capsule(chip, Color(tone, 0.18), tone, 2, 8, 2))
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.tooltip_text = "Click to put it back"
		row.add_child(chip)
		var said := DeepUi.hbox(chip, 4)
		said.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var drawn: Control = DiceIcons.picker_face(20.0, int(face.get("value", 0)), DiceIcons.die_palette(die).body, str(die.get("shape", "D6")), true, DiceIcons.face_text(int(face.get("value", 0)), str(face.get("kind", "plain"))))
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		said.add_child(drawn)
		DeepUi.label(said, DeepDice.describe(die), 11, DeepUi.PAPER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		DeepUi.icon(said, "cross_out", 11, DeepUi.MUTED).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var die_id: String = str(entry.get("die_id", ""))
		chip.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				pick_face(str(faces.key), [at], die_id)
				chip.accept_event())

func _lay_faces() -> void:
	## The chosen die's faces as chips in even rows, every face shown: 32 px faces (the picker's
	## own) in rows of up to `FACES_PREFERRED`, and past `ROWS_PREFERRED` rows wider rows, as
	## wide as the screen allows, before a smaller face; a smaller face (28, 24, 20) only when
	## even the widest rows would stand the sheet taller than the room above the dock. A d20 is
	## two rows of ten, a d30 three of ten, a d50 three of seventeen, a d100 four of twenty-five,
	## all at 32 px on the 1600 × 900 canvas. Only a die that fits at none of the sizes has its
	## like faces (the same number and etching) share a chip, "12 ×4", which picks one of them.
	if _faces_job.is_empty():
		return
	var job: Dictionary = _faces_job
	_faces_job = {}
	var holder: VBoxContainer = job.holder
	if not is_instance_valid(holder):
		return
	var faces: Dictionary = job.faces
	var die: Dictionary = job.die
	var tone: Color = job.tone
	var list: Array = die.get("faces", [])
	var lowering: bool = bool(faces.get("lowering", false))
	var blanks: bool = bool(faces.get("blanks", true))
	var chips: Array = face_groups(list, lowering, blanks, false)
	var wide: float = face_room_width()
	var tall: float = face_room_height()
	var layout: Dictionary = face_layout(chips.size(), wide, tall)
	if layout.is_empty():
		chips = face_groups(list, lowering, blanks, true)
		layout = face_layout(chips.size(), wide, tall)
	if layout.is_empty():
		## Past anything the mine makes: the smallest face, as many rows as it takes.
		var least: float = float(FACE_EDGES[FACE_EDGES.size() - 1])
		var across: int = maxi(1, int(floor((wide + FACE_GAP) / (least + FACE_PAD * 2.0 + FACE_GAP))))
		layout = {"edge": least, "across": across, "rows": ceili(float(chips.size()) / float(across))}
	var edge: float = float(layout.edge)
	var per_row: int = int(layout.across)
	holder.set_meta("layout", layout)
	var multi: bool = face_most() > 1
	var chosen: int = -1 if multi else int(extras.get(str(faces.key), -1))
	var die_id: String = str(die.get("id", ""))
	## Faces chosen several at a time: this die's, by index.
	var chosen_here: Array = []
	if multi:
		for entry in chosen_faces():
			if str(entry.get("die_id", "")) == die_id:
				chosen_here.append(int(entry.get("face", -1)))
	var body: Color = DiceIcons.die_palette(die).body
	var shape: String = str(die.get("shape", "D6"))
	var key: String = str(faces.key)
	var row: HBoxContainer = null
	for at in range(chips.size()):
		if at % per_row == 0:
			row = DeepUi.hbox(holder, int(FACE_GAP))
			row.alignment = BoxContainer.ALIGNMENT_CENTER
		var group: Dictionary = chips[at]
		var indices: Array = group.indices
		var face_kind: String = str(group.kind)
		var value: int = int(group.value)
		var lit: bool = indices.has(chosen) or indices.any(func(i: Variant) -> bool: return chosen_here.has(int(i)))
		var pick := PanelContainer.new()
		pick.add_theme_stylebox_override("panel", DeepUi.ledger(Color(tone, 0.25) if lit else DeepUi.SLATE_LOW, tone if lit else DeepUi.LEDGER_LINE, 6, int(FACE_PAD), 2, 0))
		pick.mouse_filter = Control.MOUSE_FILTER_STOP
		pick.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pick.set_meta("faces", indices)
		row.add_child(pick)
		var chip := DeepUi.hbox(pick, 3)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## The face the picker always drew at 32; a smaller face keeps its number readable.
		var text: String = DiceIcons.face_text(value, face_kind)
		var drawn: Control = DiceIcons.face(edge, value, body, shape, lit, text) if edge >= 32.0 else DiceIcons.picker_face(edge, value, body, shape, lit, text)
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(drawn)
		if indices.size() > 1:
			var count := DeepUi.label(chip, "×%d" % indices.size(), 10, DeepUi.MUTED)
			count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## What is etched into it, and how many faces the chip stands for.
		var said: Array = []
		if indices.size() > 1:
			said.append("%d faces of %s" % [indices.size(), text])
		if face_kind != "plain":
			said.append("%s: %s" % [DeepDice.etching_name(face_kind), str(DeepContent.etching(face_kind).get("text", ""))])
		pick.tooltip_text = "\n".join(said)
		pick.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				pick_face(key, indices, die_id)
				pick.accept_event())

func face_room_width() -> float:
	## How wide a row of faces may run: the screen less `SIDE_ROOM` a side and the sheet's own
	## padding.
	var screen: float = size.x if size.x > 1.0 else 1600.0
	var pad: float = _block.get_theme_stylebox("panel").get_minimum_size().x if _block != null else 36.0
	return screen - SIDE_ROOM * 2.0 - pad

func face_room_height() -> float:
	## How tall the faces may stand: the room above whatever holds the foot of the screen (the
	## dock), less the margins `_place` keeps and the rest of the sheet as built without them.
	var screen: float = size.y if size.y > 1.0 else 900.0
	var room: float = maxf(0.0, screen - floor_height) - 12.0 - 16.0
	var rest: float = _block.get_combined_minimum_size().y if _block != null else 0.0
	return room - rest

func pick_face(key: String, indices: Array, die_id: String = "") -> void:
	## A chip of the face picker clicked: the face it stands for goes into `extras[key]` as a
	## real index of the die's faces. A chip standing for several like faces picks the first of
	## them that is not already chosen; one of them already chosen stays.
	## Several at a time (`face_most` over 1): the click toggles. A chip with a face of this die
	## already chosen puts it back; else the first of its faces not yet chosen is added, up to
	## the most (past it, nothing, and a soft refusal).
	if indices.is_empty():
		return
	if face_most() > 1:
		var held: Array = chosen_faces()
		for at in range(held.size()):
			if str(held[at].get("die_id", "")) == die_id and indices.has(int(held[at].get("face", -1))):
				held.remove_at(at)
				extras[key] = held
				DeepAudio.play("ui_toggle", {"volume": 0.6})
				_build()
				changed.emit()
				return
		if held.size() >= face_most():
			DeepAudio.play("ui_back", {"volume": 0.6})
			return
		held.append({"die_id": die_id, "face": int(indices[0])})
		extras[key] = held
		DeepAudio.play("ui_toggle", {"volume": 0.7})
		_build()
		changed.emit()
		return
	var chosen: int = int(extras.get(key, -1))
	if indices.has(chosen):
		return
	DeepAudio.play("ui_toggle", {"volume": 0.7})
	extras[key] = int(indices[0])
	_build()

static func face_layout(count: int, wide: float, tall: float) -> Dictionary:
	## {edge, across, rows} for `count` chips in a room `wide` × `tall`, or {} when they fit at
	## no edge of `FACE_EDGES`. At each edge, largest first: rows of up to `FACES_PREFERRED`
	## while that is no more than `ROWS_PREFERRED` rows, else `ROWS_PREFERRED` wider rows (or
	## as few as the width allows); if the height does not hold those, the fewest rows the width
	## allows. The chips are then shared evenly between the rows.
	for size_now in FACE_EDGES:
		var edge: float = float(size_now)
		var step: float = edge + FACE_PAD * 2.0 + FACE_GAP
		var across_most: int = int(floor((wide + FACE_GAP) / step))
		var rows_most: int = int(floor((tall + FACE_GAP) / step))
		if across_most < 1 or rows_most < 1 or count < 1:
			continue
		var rows: int = ceili(float(count) / float(mini(across_most, FACES_PREFERRED)))
		if rows > ROWS_PREFERRED:
			rows = maxi(ROWS_PREFERRED, ceili(float(count) / float(across_most)))
		if rows > rows_most:
			rows = ceili(float(count) / float(across_most))
		if rows <= rows_most:
			return {"edge": edge, "across": ceili(float(count) / float(rows)), "rows": rows}
	return {}

static func face_groups(list: Array, lowering: bool, blanks: bool, grouped: bool = false) -> Array:
	## The chips a die's faces make, as {value, kind, indices}: one a face, or when `grouped`
	## one for every number-and-etching the die shows, in the order the die first shows them.
	## A face that cannot be lowered (a 1, a blank) is left out when `lowering`, and blanks when
	## `blanks` is off.
	var out: Array = []
	var by_key: Dictionary = {}
	for index in range(list.size()):
		var face: Dictionary = list[index]
		var kind: String = str(face.get("kind", "plain"))
		var value: int = int(face.get("value", 0))
		if lowering and (kind == "blank" or value <= 1):
			continue
		if not blanks and kind == "blank":
			continue
		var key: String = "%d|%s" % [value, kind]
		if grouped and by_key.has(key):
			out[int(by_key[key])].indices.append(index)
			continue
		by_key[key] = out.size()
		out.append({"value": value, "kind": kind, "indices": [index]})
	return out

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
