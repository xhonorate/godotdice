extends Control
## The battlefield. The party holds the left flank, enemies hold the right, both on a
## receding diagonal so the ground reads as depth. Resolution events choreograph the
## fight: an attacker crosses to its target, lands the blow, and returns to its mark.
##
## Sides come from each unit's `side` field: -1 draws on the left facing right, +1 on
## the right facing left. Nothing here assumes which side the party is on.
##
## Nothing here decides anything. Positions, travel and damage numbers are all read
## from the authoritative snapshot and its published event log.

const SpriteActorScript = preload("res://scripts/ui/sprite_actor.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Forge = preload("res://scripts/ui/sprite_forge.gd")
const DiceIcons = preload("res://scripts/ui/dice_icons.gd")

const DASH_SECONDS := 0.46
const IMPACT_AT := 0.52
const SLOT_WIDTH := 134.0
const PLATE_WIDTH := 112.0
const SPRITE_HEIGHT := 140.0
const INTENT_HEIGHT := 42.0
const PLATE_HEIGHT := 92.0
const PLATE_GAP := 9.0
## Share of the field kept clear down the middle, so the two lines never close on
## each other however many combatants each side brings.
const CENTRE_GAP := 0.30
## Share kept clear outside the far ranks, so the back row is not cut off by the edge.
const EDGE_MARGIN := 0.08

var reduced_motion := false

var _slots: Dictionary = {}
var _order: Array[String] = []
var _floor: Control
var _overlay: Control
var _clock := 0.0
var _floaters: Array = []
var _pending: Array = []
var _accent := Color("ff7a6b")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	custom_minimum_size.y = 340
	_floor = Control.new()
	_floor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor.draw.connect(_draw_floor.bind(_floor))
	add_child(_floor)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay.bind(_overlay))
	add_child(_overlay)
	resized.connect(_relayout)

# --- snapshot -----------------------------------------------------------------

func sync(units: Array, motion_off: bool, accent: Color, on_pick: Callable, on_inspect: Callable) -> void:
	reduced_motion = motion_off
	_accent = accent
	var seen: Dictionary = {}
	for unit in units:
		seen[str(unit.id)] = true
	for id in _slots.keys():
		if not seen.has(id):
			var stale: Dictionary = _slots[id]
			if is_instance_valid(stale.root):
				stale.root.queue_free()
			_slots.erase(id)
	# Back rows are added first so front rows draw over them and win the click.
	var left: Array = []
	var right: Array = []
	for unit in units:
		if int(unit.side) < 0:
			left.append(unit)
		else:
			right.append(unit)
	_order.clear()
	var arrival: Array = []
	for index in range(maxi(left.size(), right.size()) - 1, -1, -1):
		if index < left.size():
			arrival.append(left[index])
		if index < right.size():
			arrival.append(right[index])
	for unit in arrival:
		_apply(unit, left, right)
	for unit in units:
		_order.append(str(unit.id))
	for slot_id in _slots:
		var slot: Dictionary = _slots[slot_id]
		slot.pick = on_pick
		slot.inspect = on_inspect
	_relayout()
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()

func _apply(unit: Dictionary, left: Array, right: Array) -> void:
	var id := str(unit.id)
	var slot: Dictionary = _slots.get(id, {})
	if slot.is_empty():
		slot = _make_slot(unit)
		_slots[id] = slot
	else:
		move_child(slot.root, get_child_count() - 2)
	var side := int(unit.side)
	var peers: Array = left if side < 0 else right
	var rank := 0
	for i in peers.size():
		if str(peers[i].id) == id:
			rank = i
	slot.side = side
	slot.rank = rank
	slot.peers = peers.size()
	slot.data = unit
	_dress(slot)

func _make_slot(unit: Dictionary) -> Dictionary:
	var side := int(unit.side)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = false
	add_child(root)
	move_child(root, get_child_count() - 2)
	var intents := VBoxContainer.new()
	intents.add_theme_constant_override("separation", 1)
	intents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(intents)
	var actor := SpriteActorScript.new()
	actor.facing = 1.0 if side < 0 else -1.0
	root.add_child(actor)
	var button := Button.new()
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.add_child(button)
	var plate := VBoxContainer.new()
	plate.add_theme_constant_override("separation", 2)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	var slot := {
		"id": str(unit.id), "side": side, "root": root, "actor": actor, "button": button,
		"intents": intents, "plate": plate, "home": Vector2.ZERO, "depth": 1.0,
		"dash": 0.0, "dash_to": Vector2.ZERO, "rank": 0, "peers": 1,
		"data": unit, "pick": Callable(), "inspect": Callable(), "hp": int(unit.hp)}
	button.pressed.connect(func() -> void:
		var live: Dictionary = _slots.get(str(unit.id), {})
		if live.is_empty():
			return
		if live.pick is Callable and live.pick.is_valid():
			live.pick.call(str(unit.id)))
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			var live: Dictionary = _slots.get(str(unit.id), {})
			if not live.is_empty() and live.inspect is Callable and live.inspect.is_valid():
				live.inspect.call(str(unit.id)))
	return slot

func _dress(slot: Dictionary) -> void:
	var unit: Dictionary = slot.data
	var downed := bool(unit.get("downed", false))
	var actor = slot.actor
	actor.setup(Forge.unit(str(unit.get("key", "ENEMY")).to_upper()), Color(unit.get("tint", Color.WHITE)), reduced_motion)
	actor.downed = downed
	actor.targeted = bool(unit.get("targeted", false))
	actor.show_ground = false
	actor.idle_speed = 0.85 if unit.get("boss", false) else 1.1
	if int(unit.hp) < int(slot.hp):
		actor.flinch()
	slot.hp = int(unit.hp)
	slot.button.tooltip_text = "%s\n%s" % [str(unit.get("name", "")), str(unit.get("hint", "Right-click to inspect."))]
	slot.button.disabled = bool(unit.get("pick_disabled", false))
	for child in slot.intents.get_children():
		child.queue_free()
	for child in slot.plate.get_children():
		child.queue_free()
	var forecast: Array = unit.get("forecast", [])
	for entry in forecast:
		# One strip per plan, icons only: they already carry the outcome. The skill's
		# name and its recipient stay on the tooltip rather than crowding the field.
		var strip := HBoxContainer.new()
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_theme_constant_override("separation", 6)
		strip.mouse_filter = Control.MOUSE_FILTER_PASS
		var target := str(entry.get("target", ""))
		strip.tooltip_text = str(entry.get("name", ""))
		if not target.is_empty():
			strip.tooltip_text += "  →  " + target
		slot.intents.add_child(strip)
		var marks: Array = entry.get("marks", [])
		if marks.is_empty():
			# A dormant gem or a pure-utility action still deserves a name on screen.
			strip.add_child(_caption(str(entry.get("name", "")), UiKit.AMBER, 11))
		for mark in marks:
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
			cell.tooltip_text = "%s: %d" % [str(mark[3]), int(mark[1])]
			strip.add_child(cell)
			UiKit.icon(cell, Forge.prop(str(mark[0])), 19, Color(mark[2])).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(_caption(str(int(mark[1])), Color(mark[2]), 14))
	for intent in unit.get("intents", []):
		slot.intents.add_child(_caption(str(intent), UiKit.AMBER, 11))
	var title := Label.new()
	title.text = str(unit.get("name", ""))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UiKit.AMBER if unit.get("boss", false) else (UiKit.GOLD if unit.get("mine", false) else UiKit.PAPER))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.plate.add_child(title)
	var bar: Control = UiKit.meter(slot.plate, float(unit.hp), float(unit.max_hp),
		Color("4b5666") if downed else Color(unit.get("bar", UiKit.RED)), 13,
		"%d / %d" % [int(unit.hp), int(unit.max_hp)])
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand: Array = unit.get("hand", [])
	if not hand.is_empty():
		var roll := HBoxContainer.new()
		roll.alignment = BoxContainer.ALIGNMENT_CENTER
		roll.add_theme_constant_override("separation", 3)
		roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.plate.add_child(roll)
		for face in hand:
			roll.add_child(DiceIcons.face(20.0, int(face.get("value", 0)),
				DiceIcons.palette(str(face.get("key", "D6"))).body, str(face.get("shape", "D6")), true))
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.plate.add_child(chips)
	if int(unit.get("block", 0)) > 0:
		UiKit.chip(chips, "BLK %d" % int(unit.block), UiKit.BLUE, 10)
	for badge in unit.get("badges", []):
		UiKit.chip(chips, str(badge[0]), Color(badge[1]), 10)

# --- layout -------------------------------------------------------------------

func _caption(text: String, tone: Color, size_px: int) -> Label:
	## Field text always carries an outline: it is read against sprites and ground.
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", tone)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _relayout() -> void:
	var width := size.x
	var height := size.y
	if width <= 1.0 or height <= 1.0:
		return
	var ground := height * 0.70
	var depth_span := height * 0.20
	for id in _slots:
		var slot: Dictionary = _slots[id]
		var count: int = maxi(1, int(slot.peers))
		var t: float = 0.5 if count == 1 else float(slot.rank) / float(count - 1)
		# Rank 0 stands closest to the middle; the last rank stands furthest back.
		var inner: float = 0.5 - CENTRE_GAP * 0.5
		var near: float = inner if int(slot.side) < 0 else 1.0 - inner
		var far: float = EDGE_MARGIN if int(slot.side) < 0 else 1.0 - EDGE_MARGIN
		var x: float = lerpf(near, far, t) * width
		var y: float = ground - t * depth_span
		slot.depth = lerpf(1.0, 0.80, t)
		slot.home = Vector2(x, y)
		_place(slot)

func _place(slot: Dictionary) -> void:
	var sprite_height: float = SPRITE_HEIGHT * float(slot.depth)
	var intent_height: float = maxf(INTENT_HEIGHT, slot.intents.get_combined_minimum_size().y) if slot.intents.get_child_count() > 0 else 0.0
	var offset := Vector2.ZERO
	if float(slot.dash) > 0.0:
		var travel: float = sin(PI * float(slot.dash))
		offset = Vector2(slot.dash_to) * travel - Vector2(0, 16.0 * travel)
	var feet: Vector2 = Vector2(slot.home) + offset
	var root: Control = slot.root
	root.size = Vector2(SLOT_WIDTH, intent_height + sprite_height + PLATE_GAP + PLATE_HEIGHT)
	root.position = Vector2(feet.x - SLOT_WIDTH * 0.5, feet.y - intent_height - sprite_height)
	slot.intents.position = Vector2.ZERO
	slot.intents.size = Vector2(SLOT_WIDTH, intent_height)
	slot.actor.position = Vector2(0, intent_height)
	slot.actor.size = Vector2(SLOT_WIDTH, sprite_height)
	slot.button.position = Vector2(SLOT_WIDTH * 0.22, intent_height)
	slot.button.size = Vector2(SLOT_WIDTH * 0.56, sprite_height)
	slot.plate.position = Vector2((SLOT_WIDTH - PLATE_WIDTH) * 0.5, intent_height + sprite_height + PLATE_GAP)
	slot.plate.size = Vector2(PLATE_WIDTH, PLATE_HEIGHT)

# --- choreography -------------------------------------------------------------

func perform(event: Dictionary) -> void:
	## Plays one authoritative log entry. Presentation only: the outcome already happened.
	var kind := str(event.get("kind", ""))
	var actor_id := str(event.get("actor", event.get("actor_id", "")))
	var target_id := str(event.get("target", event.get("target_id", "")))
	var amount := int(event.get("amount", 0))
	var attacker: Dictionary = _slots.get(actor_id, {})
	var victim: Dictionary = _slots.get(target_id, {})
	var caption := ""
	var tone := UiKit.RED
	var hostile := false
	match kind:
		"damage":
			hostile = true
			var loss := int(event.get("hp_loss", amount))
			var absorbed := int(event.get("block_absorbed", 0))
			if loss > 0:
				caption = "-%d" % loss
			elif absorbed > 0:
				caption = "BLOCKED %d" % absorbed
				tone = UiKit.BLUE
			else:
				caption = "NO EFFECT"
				tone = UiKit.MUTED
		"heal":
			if amount <= 0:
				return
			caption = "+%d" % amount
			tone = UiKit.GREEN
		"block":
			if amount <= 0:
				return
			caption = "+%d BLOCK" % amount
			tone = UiKit.BLUE
		"remove_block":
			hostile = true
			caption = "-%d BLOCK" % amount
			tone = UiKit.BLUE
		"poison", "status", "stun":
			hostile = true
			caption = "%s %d" % [kind.to_upper(), amount] if amount > 0 else kind.to_upper()
			tone = Color("9bdc3c") if kind == "poison" else UiKit.AMBER
		"lifeline":
			caption = "REVIVED"
			tone = UiKit.AMBER
		"skill":
			if not attacker.is_empty():
				attacker.actor.channel()
			return
		_:
			return
	if attacker.is_empty() and victim.is_empty():
		return
	var charges := hostile and not victim.is_empty() and not attacker.is_empty() and actor_id != target_id and not reduced_motion
	if not attacker.is_empty():
		if charges:
			var toward: Vector2 = Vector2(victim.home) - Vector2(attacker.home)
			attacker.dash_to = toward - toward.normalized() * minf(toward.length() * 0.30, 96.0)
			attacker.dash = 0.0001
		if hostile:
			attacker.actor.strike()
		else:
			attacker.actor.channel()
	if victim.is_empty():
		return
	_pending.append({
		"id": target_id, "at": _clock + (DASH_SECONDS * IMPACT_AT if charges else 0.04),
		"text": caption, "tone": tone, "hostile": hostile})

func _process(delta: float) -> void:
	_clock += delta
	var moving := false
	for id in _slots:
		var slot: Dictionary = _slots[id]
		if float(slot.dash) > 0.0:
			slot.dash = float(slot.dash) + delta / DASH_SECONDS
			if float(slot.dash) >= 1.0:
				slot.dash = 0.0
			_place(slot)
			moving = true
	var index := 0
	while index < _pending.size():
		var hit: Dictionary = _pending[index]
		if _clock < float(hit.at):
			index += 1
			continue
		_pending.remove_at(index)
		var slot: Dictionary = _slots.get(str(hit.id), {})
		if slot.is_empty():
			continue
		if bool(hit.hostile):
			slot.actor.flinch()
		else:
			slot.actor.channel()
		if not str(hit.text).is_empty():
			_floaters.append({"at": Vector2(slot.home) - Vector2(0, SPRITE_HEIGHT * float(slot.depth) * 0.85),
				"text": str(hit.text), "tone": Color(hit.tone), "age": 0.0})
	for floater in _floaters:
		floater.age = float(floater.age) + delta
	var kept: Array = []
	for floater in _floaters:
		if float(floater.age) < 1.4:
			kept.append(floater)
	_floaters = kept
	if is_instance_valid(_overlay) and (not _floaters.is_empty() or moving):
		_overlay.queue_redraw()
	if is_instance_valid(_floor) and not reduced_motion:
		_floor.queue_redraw()

# --- painting -----------------------------------------------------------------

func _draw_floor(target: Control) -> void:
	var width := target.size.x
	var height := target.size.y
	if width <= 1.0:
		return
	var horizon := height * 0.54
	target.draw_rect(Rect2(0, horizon, width, height - horizon), Color(0.04, 0.05, 0.08, 0.35), true)
	for i in 9:
		var t := float(i) / 8.0
		var y := lerpf(horizon, height, t * t)
		target.draw_line(Vector2(width * (0.5 - 0.5 * t - 0.02), y), Vector2(width * (0.5 + 0.5 * t + 0.02), y), Color(_accent, 0.09 + 0.07 * t), 1.0)
	target.draw_line(Vector2(0, horizon), Vector2(width, horizon), Color(_accent, 0.22), 1.0)
	for id in _slots:
		var slot: Dictionary = _slots[id]
		var mark: Vector2 = Vector2(slot.home)
		if float(slot.dash) > 0.0:
			mark += Vector2(slot.dash_to) * sin(PI * float(slot.dash))
		var radius: float = 40.0 * float(slot.depth)
		var unit: Dictionary = slot.data
		var tone: Color = Color(unit.get("bar", UiKit.RED))
		target.draw_set_transform(mark, 0.0, Vector2(1.0, 0.30))
		target.draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.34))
		if bool(unit.get("targeted", false)):
			var pulse := 0.45 + 0.25 * sin(_clock * 4.0)
			target.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(UiKit.GOLD, pulse), 5.0, true)
		elif bool(unit.get("mine", false)):
			target.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(tone, 0.55), 4.0, true)
		else:
			target.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(tone, 0.22), 3.0, true)
		target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_overlay(target: Control) -> void:
	var font := ThemeDB.fallback_font
	for floater in _floaters:
		var age := float(floater.age)
		var rise := ease(minf(age / 1.4, 1.0), 0.35) * 54.0
		var fade := clampf(1.0 - (age - 0.9) / 0.5, 0.0, 1.0)
		var text := str(floater.text)
		var font_size := 26 if text.begins_with("-") else 20
		var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var at: Vector2 = Vector2(floater.at) - Vector2(measured.x * 0.5, rise)
		target.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, fade))
		target.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(floater.tone, fade))
