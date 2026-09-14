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
const DiceViewScript = preload("res://scripts/ui/dice_view.gd")
const GemIcons = preload("res://scripts/ui/gem_icons.gd")
const GemText = preload("res://scripts/ui/gem_text.gd")

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

## --- activation choreography --------------------------------------------------
## A cast is read in one pass: the stone lights and names itself, the dice that met its
## trigger fly up into it, and the number they came to is refined a rank at a time until
## the amount the log recorded is standing on its own.
const CAST_IGNITE := 0.16
const CAST_TRAVEL_FROM := 0.12
const CAST_TRAVEL_TO := 0.44
const CAST_BASE_AT := 0.46
## One refinement — Clarity, then Cut, then Carat — occupies this long.
const CAST_STEP_SPAN := 0.17
## The shortest a cast can be. An enemy intent carries no ranks to refine, so without a
## floor its number would be gone before it could be read.
const CAST_MIN_DWELL := 0.62
## How long the settled amount stands after the chain finishes.
const CAST_HOLD := 0.44
## A throw, plus a moment to read what it lit. `DiceView` spins for 0.72s.
const ROLL_DWELL := 1.15
## Text baselines above the stone, measured from it. The column reads downward — name,
## amount, the ranks that moved it — and each band keeps a lane of its own.
const NAME_LANE := 78.0
const VALUE_LANE := 47.0
const RANK_LANE := 25.0
const CLARITY_TONE := Color("cfe4ff")
const CUT_TONE := Color("9fd8ff")
const CARAT_TONE := Color("e8b661")
## What each kind of amount is worth reading as, once it has finished resolving.
const EFFECT_TONES := {
	"damage": Color("ff7a6b"), "block": Color("76b6ff"), "heal": Color("6fe3b0"),
	"lifeline": Color("ffcf7a"), "poison": Color("9bdc3c"), "stun": Color("ffcf7a"),
	"remove_block": Color("b98bff"), "gold": Color("e8b661"), "echo": Color("b98bff")}

var reduced_motion := false
## Right-click on something carried over a combatant's head: (unit id, entry id).
var inspect_skill: Callable
## Playback speed, mirrored from the interface setting so choreography keeps pace with
## the log rather than drifting behind a player who has sped the fight up.
var speed := 1.0

var _slots: Dictionary = {}
var _order: Array[String] = []
var _floor: Control
var _overlay: Control
var _clock := 0.0
var _floaters: Array = []
var _pending: Array = []
var _casts: Array = []
var _banner: Dictionary = {}
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
	var loadout := HBoxContainer.new()
	loadout.alignment = BoxContainer.ALIGNMENT_CENTER
	loadout.add_theme_constant_override("separation", 3)
	loadout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(loadout)
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
		"intents": intents, "plate": plate, "loadout": loadout, "home": Vector2.ZERO, "depth": 1.0,
		"dash": 0.0, "dash_to": Vector2.ZERO, "rank": 0, "peers": 1,
		"loadout_cells": {}, "dice_cells": {}, "solids": {},
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
	# Solids outlive a re-dress so a throw in flight is not rebuilt out from under itself.
	for die_id in slot.solids:
		var kept: Control = slot.solids[die_id]
		if is_instance_valid(kept) and kept.get_parent() != null:
			kept.get_parent().remove_child(kept)
	for child in slot.loadout.get_children():
		# Out of the row now, not at the end of the frame: a row still holding the old stones
		# measures twice as wide and would be placed for a loadout that is not there.
		slot.loadout.remove_child(child)
		child.queue_free()
	for child in slot.intents.get_children():
		child.queue_free()
	for child in slot.plate.get_children():
		child.queue_free()
	slot.loadout_cells = {}
	slot.dice_cells = {}
	# What a combatant is carrying, small enough to sit over the head the way the roll sits
	# under the feet: the party's stones, and the other side's roster of named moves. It is
	# the anchor an activation lights up, so every turn is followed on whoever is taking it.
	for entry in unit.get("loadout", []):
		var cell := _loadout_cell(slot.loadout, entry, str(unit.id))
		slot.loadout_cells[str(entry.get("id", ""))] = cell
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
			var die_id := str(face.get("die_id", ""))
			var solid: bool = bool(unit.get("solid", false)) and not face.get("die", {}).is_empty()
			var pip: Control = _solid(slot, die_id) if solid else DiceIcons.face(
				20.0, int(face.get("value", 0)), DiceIcons.palette(str(face.get("key", "D6"))).body,
				str(face.get("shape", "D6")), true)
			roll.add_child(pip)
			# A solid builds its geometry on entering the tree, so it is dressed only once
			# it is standing in the row it belongs to.
			if solid:
				pip.configure(face.die, face.roll, false, false, Color(unit.get("bar", UiKit.RED)))
			slot.dice_cells[die_id] = pip
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.plate.add_child(chips)
	if int(unit.get("block", 0)) > 0:
		UiKit.chip(chips, "BLK %d" % int(unit.block), UiKit.BLUE)
	for badge in unit.get("badges", []):
		UiKit.chip(chips, str(badge[0]), Color(badge[1]), 10)

func _solid(slot: Dictionary, die_id: String) -> Control:
	## A real die on the plate, pooled per die so a throw spins once and settles. The view
	## does not drift between rolls: several of these stand on the field at a time, and only
	## the one being thrown has anything to say.
	var view: Variant = slot.solids.get(die_id, null)
	if view == null or not is_instance_valid(view):
		view = DiceViewScript.new()
		view.live = false
		view.custom_minimum_size = Vector2(24, 24)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.solids[die_id] = view
	return view

func _loadout_cell(parent: Node, entry: Dictionary, unit_id: String) -> Control:
	## One carried stone, drawn as its own emblem in its own colour. A dormant one is
	## dimmed rather than hidden: an ally's loadout should read the same from turn to turn.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(20, 20)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.tooltip_text = str(entry.get("tip", ""))
	holder.set_meta("loadout_entry", entry)
	holder.mouse_default_cursor_shape = Control.CURSOR_HELP
	holder.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and inspect_skill.is_valid():
			holder.accept_event()
			inspect_skill.call(unit_id, str(entry.get("id", ""))))
	parent.add_child(holder)
	var image := TextureRect.new()
	image.texture = GemIcons.texture(str(entry.get("glyph", "sword")), 20)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := Color(entry.get("tint", UiKit.PAPER))
	image.modulate = tint if not bool(entry.get("dim", false)) else Color(tint, 0.42)
	holder.add_child(image)
	return holder

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
	var loadout_height: float = slot.loadout.get_combined_minimum_size().y if slot.loadout.get_child_count() > 0 else 0.0
	var intent_height: float = maxf(INTENT_HEIGHT, slot.intents.get_combined_minimum_size().y) if slot.intents.get_child_count() > 0 else 0.0
	var offset := Vector2.ZERO
	if float(slot.dash) > 0.0:
		var travel: float = sin(PI * float(slot.dash))
		offset = Vector2(slot.dash_to) * travel - Vector2(0, 16.0 * travel)
	var feet: Vector2 = Vector2(slot.home) + offset
	var root: Control = slot.root
	root.size = Vector2(SLOT_WIDTH, loadout_height + intent_height + sprite_height + PLATE_GAP + PLATE_HEIGHT)
	root.position = Vector2(feet.x - SLOT_WIDTH * 0.5, feet.y - loadout_height - intent_height - sprite_height)
	# A long loadout is wider than the slot. It grows out from the middle of the head rather
	# than from the slot's left edge, so six stones sit as centred as three do.
	var loadout_width: float = maxf(SLOT_WIDTH, slot.loadout.get_combined_minimum_size().x)
	slot.loadout.size = Vector2(loadout_width, loadout_height)
	slot.loadout.position = Vector2((SLOT_WIDTH - loadout_width) * 0.5, 0.0)
	slot.intents.position = Vector2(0, loadout_height)
	slot.intents.size = Vector2(SLOT_WIDTH, intent_height)
	slot.actor.position = Vector2(0, loadout_height + intent_height)
	slot.actor.size = Vector2(SLOT_WIDTH, sprite_height)
	slot.button.position = Vector2(SLOT_WIDTH * 0.22, loadout_height + intent_height)
	slot.button.size = Vector2(SLOT_WIDTH * 0.56, sprite_height)
	slot.plate.position = Vector2((SLOT_WIDTH - PLATE_WIDTH) * 0.5, loadout_height + intent_height + sprite_height + PLATE_GAP)
	slot.plate.size = Vector2(PLATE_WIDTH, PLATE_HEIGHT)

# --- choreography -------------------------------------------------------------

func announce(text: String, tone: Color) -> void:
	## A band drawn across the field when the initiative changes hands, so a long fight
	## never leaves the player guessing whose slot they are watching.
	if reduced_motion:
		return
	_banner = {"text": text, "tone": tone, "age": 0.0}
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()

func perform(event: Dictionary) -> float:
	## Plays one authoritative log entry and answers how long it wants the floor for.
	## Presentation only: the outcome already happened.
	var kind := str(event.get("kind", ""))
	var actor_id := str(event.get("actor", event.get("actor_id", "")))
	var target_id := str(event.get("target", event.get("target_id", "")))
	var amount := int(event.get("amount", 0))
	var attacker: Dictionary = _slots.get(actor_id, {})
	var victim: Dictionary = _slots.get(target_id, {})
	var caption := ""
	var tone := UiKit.RED
	var hostile := false
	var dwell := 0.5
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
				return 0.0
			caption = "+%d" % amount
			tone = UiKit.GREEN
		"block":
			if amount <= 0:
				return 0.0
			caption = "+%d BLOCK" % amount
			tone = UiKit.BLUE
		"remove_block":
			hostile = true
			caption = "-%d BLOCK" % amount
			tone = UiKit.BLUE
		"poison", "poison_tick", "status", "stun":
			hostile = true
			dwell = 0.42
			if kind == "poison_tick":
				caption = "-%d POISON" % int(event.get("hp_loss", amount))
			else:
				caption = "%s %d" % [str(event.get("status", kind)).to_upper(), amount] if amount > 0 else kind.to_upper()
			tone = Color("9bdc3c") if kind in ["poison", "poison_tick"] else UiKit.AMBER
		"lifeline", "revive":
			caption = "REVIVED"
			tone = UiKit.AMBER
		"roll":
			# The caller re-syncs the field on this event, which puts the dice on the plate
			# and lights the roster. All this owes it is the room to be watched: the throw
			# has to land before the first of its actions opens.
			if not attacker.is_empty():
				attacker.actor.channel()
			return 0.35 if reduced_motion else ROLL_DWELL
		"skill":
			return _cast(event, attacker)
		_:
			return 0.0
	if attacker.is_empty() and victim.is_empty():
		return 0.0
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
		return dwell
	_pending.append({
		"id": target_id, "at": _clock + (DASH_SECONDS * IMPACT_AT if charges else 0.04),
		"text": caption, "tone": tone, "hostile": hostile})
	return dwell

func _cast(event: Dictionary, slot: Dictionary) -> float:
	## Opens an activation: the stone lights, the dice that met its trigger rise into it,
	## and the amount the log already recorded is assembled a rank at a time.
	if slot.is_empty():
		return 0.0
	slot.actor.channel()
	var dice: Array = event.get("dice", [])
	var base := 0
	for entry in dice:
		base += int(entry.get("value", 0))
	var amounts: Array = event.get("amounts", [])
	var headline: Dictionary = amounts[0] if not amounts.is_empty() else {}
	var final_amount := int(headline.get("amount", 0))
	var final_kind := str(headline.get("kind", ""))
	var carat := int(event.get("carat", 0))
	var chain: Array = []
	if carat > 0:
		# The refinement the gem sheet prints, run backwards from the recorded amount. It
		# names only the ranks this rule actually applies, so a Cut that chooses how many
		# dice are read never appears here as a multiplication.
		var refined: Dictionary = GemText.chain(
			{"key": str(event.get("skill", "")), "carat": carat,
				"cut": int(event.get("cut", 1)), "clarity": int(event.get("clarity", 1))},
			final_kind, final_amount, int(event.get("clarity", 1)))
		if not refined.is_empty():
			base = int(refined.base)
			for step in refined.steps:
				chain.append({"glyph": str(step.glyph), "tint": _rank_tone(str(step.glyph)),
					"text": str(step.text), "value": float(step.value)})
	# A rule whose shape the chain cannot reproduce gets no invented middle values: the
	# number simply eases from what the dice showed to the amount the log recorded.
	var loose := chain.is_empty() and final_amount != base and not dice.is_empty()
	var dwell := maxf(CAST_MIN_DWELL, CAST_BASE_AT + CAST_STEP_SPAN * float(maxi(chain.size(), 1 if loose else 0)))
	if reduced_motion:
		return minf(dwell, 0.2)
	# A stone is found by its own id; the other side carries no stone, so its roster entry
	# is found by the key of the action that fired.
	var cell_id := str(event.get("gem_id", ""))
	if cell_id.is_empty():
		cell_id = str(event.get("skill", ""))
	_casts.append({
		"slot": str(slot.id), "cell": cell_id,
		"name": str(event.get("skill_name", event.get("skill", ""))),
		"tint": Color(_slot_loadout_tint(slot, cell_id)),
		"dice": dice, "base": base, "chain": chain, "final": final_amount, "loose": loose,
		"final_tone": Color(EFFECT_TONES.get(final_kind, UiKit.PAPER)),
		"show_value": not amounts.is_empty(), "dwell": dwell, "age": 0.0})
	return dwell

func _rank_tone(glyph: String) -> Color:
	match glyph:
		"clarity": return CLARITY_TONE
		"cut": return CUT_TONE
		"carat": return CARAT_TONE
	return UiKit.PAPER

func _slot_loadout_tint(slot: Dictionary, cell_id: String) -> Color:
	var entries: Array = slot.data.get("loadout", [])
	for entry in entries:
		if str(entry.get("id", "")) == cell_id:
			return Color(entry.get("tint", UiKit.AMBER))
	return UiKit.AMBER

func _anchor(slot: Dictionary, cast: Dictionary) -> Vector2:
	## Where a cast converges: the stone it came from if that stone is still on screen,
	## otherwise the space just above the caster's head.
	var cell: Variant = slot.loadout_cells.get(str(cast.cell), null)
	if cell != null and is_instance_valid(cell) and (cell as Control).size.x > 0.0:
		return _local_centre(cell)
	return Vector2(slot.root.position) + Vector2(SLOT_WIDTH * 0.5, -8.0)

func _local_centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center() - global_position

func _process(delta: float) -> void:
	delta *= maxf(0.05, speed)
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
			# Over the torso rather than the head: the column above a combatant belongs to
			# whatever they are casting, and a number landing on them must not sit in it.
			_floaters.append({"at": Vector2(slot.home) - Vector2(0, SPRITE_HEIGHT * float(slot.depth) * 0.55),
				"text": str(hit.text), "tone": Color(hit.tone), "age": 0.0})
	for floater in _floaters:
		floater.age = float(floater.age) + delta
	var kept: Array = []
	for floater in _floaters:
		if float(floater.age) < 1.4:
			kept.append(floater)
	_floaters = kept
	var live_casts: Array = []
	for cast in _casts:
		cast.age = float(cast.age) + delta
		if float(cast.age) < float(cast.dwell) + CAST_HOLD:
			live_casts.append(cast)
	_casts = live_casts
	_light_loadouts()
	if not _banner.is_empty():
		_banner.age = float(_banner.age) + delta
		if float(_banner.age) > 1.0:
			_banner = {}
	if is_instance_valid(_overlay) and (not _floaters.is_empty() or not _casts.is_empty() or not _banner.is_empty() or moving):
		_overlay.queue_redraw()
	if is_instance_valid(_floor) and not reduced_motion:
		_floor.queue_redraw()

func _light_loadouts() -> void:
	## A stone that is resolving swells and burns clean; everything else sits at the weight
	## the snapshot dressed it with. Cells are looked up fresh each frame, so a re-sync
	## midway through a cast rebuilds the row without stranding the animation on a dead node.
	for id in _slots:
		var slot: Dictionary = _slots[id]
		for cell_id in slot.loadout_cells:
			var cell: Control = slot.loadout_cells[cell_id]
			if is_instance_valid(cell):
				_set_cell_lift(cell, 0.0)
	for cast in _casts:
		var slot: Dictionary = _slots.get(str(cast.slot), {})
		if slot.is_empty():
			continue
		var cell: Variant = slot.loadout_cells.get(str(cast.cell), null)
		if cell == null or not is_instance_valid(cell):
			continue
		var age := float(cast.age)
		var span := float(cast.dwell) + CAST_HOLD
		var rise := clampf(age / CAST_IGNITE, 0.0, 1.0)
		var fall := clampf((span - age) / CAST_HOLD, 0.0, 1.0)
		_set_cell_lift(cell, minf(rise, fall))

func _set_cell_lift(cell: Control, lift: float) -> void:
	var image: Node = cell.get_child(0) if cell.get_child_count() > 0 else null
	if not image is TextureRect:
		return
	var view: TextureRect = image
	view.pivot_offset = cell.size * 0.5
	view.scale = Vector2.ONE * (1.0 + 0.55 * lift)
	if lift <= 0.0:
		var entry := _cell_entry(cell)
		var tint := Color(entry.get("tint", UiKit.PAPER))
		view.modulate = tint if not bool(entry.get("dim", false)) else Color(tint, 0.42)
		return
	var base := Color(_cell_entry(cell).get("tint", UiKit.PAPER))
	view.modulate = base.lerp(Color(1, 1, 1, 1), 0.55 * lift)

func _cell_entry(cell: Control) -> Dictionary:
	return cell.get_meta("loadout_entry", {}) if cell.has_meta("loadout_entry") else {}

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
	for cast in _casts:
		_draw_cast(target, font, cast)
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
	if not _banner.is_empty():
		_draw_banner(target, font)

func _draw_banner(target: Control, font: Font) -> void:
	var age := float(_banner.age)
	var fade := clampf(minf(age / 0.15, (1.0 - age) / 0.3), 0.0, 1.0)
	if fade <= 0.0:
		return
	var tone := Color(_banner.tone)
	var text := str(_banner.text)
	var y := target.size.y * 0.07
	var band := Rect2(0, y - 20.0, target.size.x, 40.0)
	target.draw_rect(band, Color(0, 0, 0, 0.42 * fade), true)
	target.draw_line(Vector2(0, band.position.y), Vector2(target.size.x, band.position.y), Color(tone, 0.55 * fade), 1.5)
	target.draw_line(Vector2(0, band.end.y), Vector2(target.size.x, band.end.y), Color(tone, 0.55 * fade), 1.5)
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var at := Vector2((target.size.x - measured.x) * 0.5, y + measured.y * 0.30)
	target.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, fade))
	target.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(tone, fade))

func _draw_cast(target: Control, font: Font, cast: Dictionary) -> void:
	var slot: Dictionary = _slots.get(str(cast.slot), {})
	if slot.is_empty():
		return
	var age := float(cast.age)
	var dwell := float(cast.dwell)
	var span := dwell + CAST_HOLD
	var anchor := _anchor(slot, cast)
	var tint := Color(cast.tint)
	var ignite := clampf(age / CAST_IGNITE, 0.0, 1.0)
	var fade := clampf((span - age) / CAST_HOLD, 0.0, 1.0)
	# The halo behind the stone, widest as the dice land and closing as the amount settles.
	var halo := ease(ignite, 0.4) * fade
	if halo > 0.0:
		var radius := 16.0 + 9.0 * sin(minf(age, dwell) / maxf(dwell, 0.01) * PI)
		target.draw_circle(anchor, radius, Color(tint, 0.16 * halo))
		target.draw_arc(anchor, radius, 0.0, TAU, 28, Color(tint, 0.44 * halo), 2.0, true)
	# The column above the head reads downward: the stone's name, the amount it is coming
	# to, the ranks that moved it, and the stone itself. Each band has its own lane so a
	# long name and a large number are never laid over one another.
	var rise := 10.0 * ease(clampf((age - CAST_BASE_AT) / 0.6, 0.0, 1.0), 0.4)
	var name_text := str(cast.name).to_upper()
	if not name_text.is_empty():
		var measured := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var at := anchor + Vector2(-measured.x * 0.5, -NAME_LANE - rise - 4.0 * ease(ignite, 0.3))
		target.draw_string_outline(font, at, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 6, Color(0, 0, 0, fade))
		target.draw_string(font, at, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(tint, fade))
	_draw_motes(target, font, cast, slot, anchor, tint)
	if not bool(cast.show_value):
		return
	_draw_chain(target, font, cast, anchor, age, fade, rise)

func _draw_motes(target: Control, font: Font, cast: Dictionary, slot: Dictionary, anchor: Vector2, tint: Color) -> void:
	## Each contributing die sends its face up into the stone. The mote carries the value
	## it rolled, so the sum that appears next has a visible provenance.
	var age := float(cast.age)
	if age < CAST_TRAVEL_FROM or age > CAST_TRAVEL_TO + 0.12:
		return
	var dice: Array = cast.dice
	for i in dice.size():
		var die_id := str(dice[i].get("die_id", ""))
		var source: Control = slot.dice_cells.get(die_id, null)
		var from := _local_centre(source) if source != null and is_instance_valid(source) else Vector2(slot.home)
		var stagger := 0.05 * float(i)
		var t := clampf((age - CAST_TRAVEL_FROM - stagger) / maxf(CAST_TRAVEL_TO - CAST_TRAVEL_FROM, 0.01), 0.0, 1.0)
		if t <= 0.0:
			continue
		var eased := ease(t, 0.45)
		# A shallow arc out to the side, so motes from neighbouring dice stay distinct.
		var bow := Vector2(float(slot.side) * -26.0, -18.0) * sin(eased * PI)
		var at := from.lerp(anchor, eased) + bow
		var alpha := (1.0 - pow(t, 3.0))
		target.draw_circle(at, 4.0 - 2.0 * t, Color(tint, 0.85 * alpha))
		target.draw_circle(from.lerp(anchor, maxf(0.0, eased - 0.07)) + bow * 0.9, 2.4, Color(tint, 0.35 * alpha))
		var text := str(int(dice[i].get("value", 0)))
		var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var label_at := at + Vector2(-measured.x * 0.5, -7.0)
		target.draw_string_outline(font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, alpha))
		target.draw_string(font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UiKit.PAPER, alpha))

func _draw_chain(target: Control, font: Font, cast: Dictionary, anchor: Vector2, age: float, fade: float, rise: float) -> void:
	## The running amount, and the ranks that moved it. Each refinement slides in beneath
	## the number as its turn comes; the number itself eases from one value to the next and
	## finishes on the amount the log recorded, in the colour of what that amount does.
	if age < CAST_BASE_AT - 0.06:
		return
	var chain: Array = cast.chain
	var value := float(cast.base)
	var tone := Color(UiKit.PAPER)
	var lanes: int = maxi(chain.size(), 1 if bool(cast.loose) else 0)
	var resolved_at: float = CAST_BASE_AT + CAST_STEP_SPAN * float(lanes)
	for i in chain.size():
		var step_at: float = CAST_BASE_AT + CAST_STEP_SPAN * float(i)
		if age < step_at:
			break
		var t := clampf((age - step_at) / CAST_STEP_SPAN, 0.0, 1.0)
		var previous: float = float(cast.base) if i == 0 else float(chain[i - 1].value)
		value = lerpf(previous, float(chain[i].value), ease(t, 0.4))
	if bool(cast.loose):
		value = lerpf(float(cast.base), float(cast.final),
			ease(clampf((age - CAST_BASE_AT) / CAST_STEP_SPAN, 0.0, 1.0), 0.4))
	if age >= resolved_at:
		tone = Color(cast.final_tone)
		value = float(cast.final)
	var punch := 1.0
	if age >= resolved_at and age < resolved_at + 0.18:
		punch = 1.0 + 0.35 * (1.0 - (age - resolved_at) / 0.18)
	var text := str(int(round(value)))
	var font_size := int(round(26.0 * punch))
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := anchor + Vector2(-measured.x * 0.5, -VALUE_LANE - rise)
	target.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color(0, 0, 0, fade))
	target.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(tone, fade))
	# The ranks that did the work, laid out under the number in the order they applied.
	var shown: Array = []
	for i in chain.size():
		if age >= CAST_BASE_AT + CAST_STEP_SPAN * float(i):
			shown.append(chain[i])
	if shown.is_empty():
		return
	var width := 0.0
	var widths: Array = []
	for step in shown:
		var step_width: float = 15.0 + 2.0 + font.get_string_size(str(step.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		widths.append(step_width)
		width += step_width + 6.0
	var cursor := anchor.x - (width - 6.0) * 0.5
	var row_y := anchor.y - RANK_LANE - rise
	for i in shown.size():
		var step: Dictionary = shown[i]
		var appear := clampf((age - CAST_BASE_AT - CAST_STEP_SPAN * float(i)) / 0.12, 0.0, 1.0)
		var alpha := fade * appear
		var glyph := GemIcons.texture(str(step.glyph), 15)
		target.draw_texture_rect(glyph, Rect2(cursor, row_y - 11.0, 15.0, 15.0), false, Color(step.tint, alpha))
		var label_at := Vector2(cursor + 17.0, row_y)
		target.draw_string_outline(font, label_at, str(step.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, Color(0, 0, 0, alpha))
		target.draw_string(font, label_at, str(step.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(step.tint, alpha))
		cursor += float(widths[i]) + 6.0
