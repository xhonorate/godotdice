extends Control
## A creature's inset tag at its feet (the plates rethink, artifact NMAGkwooypHHUKxsB4tR71,
## the owner's final room of round eleven): its action dice stand in at the left, real solids
## with their engraved marks, and beside them its name, its health with its block hatched over
## the end, and one row of grey pills, each a move's coloured mark and its number. A Warden's
## pills also say their names while the row stays narrow enough; nothing wraps or clips. What
## is on it hangs under the tag as the party's own chips do, and what it pinned on itself for a
## turn (a Lantern, a Static, a Gravity) is a chip there while it lasts.
##
## Several dice stand nearly as big as one, overlapped in a fan (the owner, October 28): the
## front one at the right by the name, each behind it a step to the left and a little higher.
## When it throws, a die from behind swaps round to the front over the others first; the die
## grows 1.7 times about its right edge and middle, tumbles and lands, and what it landed on is
## a pill over the die, never over the creature's head. Left-click targets it, right-click
## opens its die; hovering it hands the ledger panel to it.

const DiceView = preload("res://view/dice/dice_view.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const Look = preload("res://view/battle/creature_look.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")
const ScreenFx = preload("res://view/battle/screen_fx.gd")
const CameraRig = preload("res://view/battle/camera_rig.gd")

signal pressed
signal inspect
signal hovered(on: bool)

## How much a die grows as it is thrown.
const GROW: float = 1.7
## How big the solid is drawn against its place on the tag: the camera frames a die with room
## round it, so the picture is drawn larger than the place for the die to fill it.
const FRAME: float = 1.45
## How much of its place the die itself fills, at rest.
const DIE_FILL: float = 0.96
## How long a die thrown from behind the stack takes to swap round to the front.
const SWAP: float = 0.22
## The room the dice stand in at the tag's left, at the least.
const INSET: float = 60.0
const MIN_WIDTH: float = 150.0
## A Warden's tag is at least this wide, and its pills say their names while its row stays
## inside NAMED_MOST.
const WARDEN_WIDTH: float = 330.0
const NAMED_MOST: float = 660.0
const FILL := Color(0.067, 0.078, 0.114, 0.95)
const LINE := Color("2f3752")
const HOVER_LINE := Color("c5cde3")

var fading: bool = false
## Where it stands, eased after its creature's feet; the screen places it.
var rest: Vector2 = Vector2.ZERO
var panel: PanelContainer
var _box: VBoxContainer
var _name: Label
var _bar: HealthBar
var _pills: HBoxContainer
var _dice: Control
## One a die, in the order of its dice: {holder, view, id, shape, edge, token, place}, its
## place in the stack 0 at the front.
var _holders: Array = []
## Where each place in the stack stands, front first (`dice_spots`).
var _spots: Array = []
var _swap: Tween = null
var _block: PanelContainer
var _block_label: Label
var _chips: EffectChips.Row
var _result: PanelContainer
var _result_row: HBoxContainer
var _result_label: Label
var _result_mark: TextureRect
var _pill_of: Dictionary = {}
var _dice_key: String = ""
var _pills_key: String = ""
var _style_key: String = ""
var _targeted: bool = false
var _acting: bool = false
var _dimmed: bool = false
var _hover: bool = false
var _warden: bool = false
var _inset: float = INSET
var _rolling: int = -1
var _breath: Tween = null
var _landing: Tween = null
var _foe: Dictionary = {}
var _party: int = 1

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	_box = DeepUi.vbox(panel, 4)
	_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_name = DeepUi.label(_box, "", 12, DeepUi.PAPER)
	_name.add_theme_font_override("font", DeepUi.bold_font())
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bar = HealthBar.new()
	_box.add_child(_bar)
	_pills = DeepUi.hbox(_box, 4)
	_pills.mouse_filter = Control.MOUSE_FILTER_PASS
	## The statuses hang under the tag, beside where its dice stand.
	_chips = EffectChips.Row.new(13)
	_chips.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_chips)
	## The dice over the panel's left end, and the block chip over its top right corner.
	_dice = Control.new()
	_dice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dice)
	_block = PanelContainer.new()
	_block.mouse_filter = Control.MOUSE_FILTER_PASS
	_block.add_theme_stylebox_override("panel", DeepUi.capsule(_block, Color("14223a"), DeepUi.BLOCK, 2, 6, 0))
	add_child(_block)
	var block_row := DeepUi.hbox(_block, 3)
	block_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DeepUi.icon(block_row, "shield", 11, Color("9cc4ff")).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_label = DeepUi.label(block_row, "", 11, Color("cfe2ff"))
	_block_label.add_theme_font_override("font", DeepUi.bold_font())
	_block.visible = false
	Tips.attach(_block, func() -> Control: return Plates.words("Block", "Soaks %s damage before its health." % _block_label.text, "", DeepUi.BLOCK), {"tone": DeepUi.BLOCK})
	## What it landed on, over the die.
	_result = PanelContainer.new()
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.visible = false
	_result.z_index = 2
	add_child(_result)
	_result_row = DeepUi.hbox(_result, 5)
	_result_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_mark = Look.mark(_result_row, "f_sword", 15, Color.WHITE)
	_result_label = DeepUi.label(_result_row, "", 13, DeepUi.PAPER)
	_result_label.add_theme_font_override("font", DeepUi.bold_font())
	_style()
	gui_input.connect(_on_input)
	mouse_entered.connect(func() -> void: hovered.emit(true))
	mouse_exited.connect(func() -> void: hovered.emit(false))
	panel.minimum_size_changed.connect(_relayout)

func _on_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		inspect.emit()
		accept_event()

# --- the look ------------------------------------------------------------------------------------

func _style() -> void:
	## Lit gold when it is the target, the colour of a blow (and breathing) while it acts, pale
	## under the pointer, the Ledger line otherwise.
	var key: String = "%s|%s|%s|%s" % [_targeted, _acting, _hover, _inset]
	if key == _style_key:
		return
	_style_key = key
	var line: Color = LINE
	var width: int = 2
	if _acting:
		line = DeepUi.BAD
		width = 3
	elif _targeted:
		line = DeepUi.ACCENT
		width = 3
	elif _hover:
		line = HOVER_LINE
	var style := DeepUi.ledger(FILL, line, 9, 7, width, 4)
	style.content_margin_left = _inset
	style.content_margin_right = 10
	if _acting:
		style.shadow_color = Color(DeepUi.BAD, 0.35)
		style.shadow_size = 12
		style.shadow_offset = Vector2.ZERO
	if _breath != null and _breath.is_valid():
		_breath.kill()
	_breath = null
	if _acting and not DeepUi.headless() and not ScreenFx.calm and is_inside_tree():
		_breath = create_tween().set_loops()
		_breath.tween_property(style, "shadow_color:a", 0.12, 0.6).set_trans(Tween.TRANS_SINE)
		_breath.tween_property(style, "shadow_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	panel.add_theme_stylebox_override("panel", style)

func set_spot(acting: bool, dimmed: bool) -> void:
	## Whether this creature is the one acting, or another one is.
	if fading:
		return
	if dimmed != _dimmed:
		_dimmed = dimmed
		var alpha: float = 0.6 if dimmed else 1.0
		if DeepUi.headless() or not is_inside_tree():
			modulate.a = alpha
		else:
			create_tween().tween_property(self, "modulate:a", alpha, 0.2).set_trans(Tween.TRANS_SINE)
	if acting == _acting:
		return
	_acting = acting
	_style()

func set_looked(on: bool) -> void:
	## The creature under the pointer (on its tag or in the room): a pale edge.
	if on != _hover:
		_hover = on
		_style()

func is_acting() -> bool:
	return _acting

func is_targeted() -> bool:
	return _targeted

# --- what it shows -------------------------------------------------------------------------------

func update(foe: Dictionary, battle: Dictionary, targeted: bool, preview: int) -> void:
	_foe = foe
	_party = maxi(1, battle.get("players", []).size())
	_warden = bool(foe.get("warden", false))
	if targeted != _targeted:
		_targeted = targeted
		_style()
		if targeted:
			DeepUi.pulse(self, 1.05, 0.3)
	_name.text = str(foe.get("name", "")).to_upper()
	_name.add_theme_color_override("font_color", Color("ffb0a0") if _warden else DeepUi.PAPER)
	var max_hp: int = maxi(1, int(foe.get("max_hp", 1)))
	var hp: int = maxi(0, int(foe.get("hp", 0)))
	var block: int = int(foe.get("block", 0))
	_bar.thick = _warden
	_bar.show_health(float(hp) / float(max_hp), "%s / %s" % [DeepUi.number(hp), DeepUi.number(max_hp)], clampf(float(block) / float(max_hp), 0.0, 0.4))
	_bar.preview = clampf(float(maxi(0, preview - block)) / float(max_hp), 0.0, 1.0)
	_block.visible = block > 0
	_block_label.text = DeepUi.number(block)
	_sync_dice(foe)
	_sync_pills(foe)
	_sync_chips(foe, battle)
	_relayout()

func _sync_chips(foe: Dictionary, battle: Dictionary) -> void:
	## Its statuses as the party's chips, without its block (the corner chip says it) or what
	## it always is (the ledger says that); and what it pinned on itself until its next action.
	var pinned: Dictionary = foe.get("pinned", {}) if foe.get("pinned", null) is Dictionary else {}
	var shown: Array = []
	for chip in EffectChips.for_enemy(foe, battle):
		var key: String = str(chip.get("key", ""))
		if key == "block" or str(chip.get("span", "")) == "trait":
			continue
		shown.append(chip)
	for name in pinned:
		shown.append(pinned_chip(foe, str(name)))
	_chips.show_effects(shown)

## What a creature pins on itself for the party's turn, by the move that does it (Lantern,
## Static, Hush, Dampen, Roller, Gravity) and the Paradox Moth's whole-bowl rerolls.
const PINNED: Dictionary = {
	"gift_rerolls": ["reroll", "Lantern", "Its light gives every player an extra reroll on the next turn. It goes out as its next action opens."],
	"reroll_all": ["reroll", "Paradox", "Until its next action, a reroll throws your whole bowl again."],
	"backlash": ["bolt", "Static", "Until its next action, every gem that fires costs its owner 1 health."],
	"resonance_damp": ["cross_out", "Hush", "Until its next action, your gems ring for %d%% less Resonance."],
	"roll_for_you": ["die", "Roller", "It throws your dice for you on the next turn: no rerolls. It lets go as its next action opens."],
	"taunt": ["magnet", "Gravity", "Until its next action, gems aimed at one creature hit it instead. Gems that hit every creature are not bent."]}

static func pinned_chip(foe: Dictionary, name: String) -> Dictionary:
	## A pinned trait as a violet chip with one turn on its bar: it comes off as the creature's
	## next action opens.
	var said: Array = PINNED.get(name, ["spark", name.capitalize(), "Until its next action opens."])
	var title: String = str(said[1])
	var text: String = str(said[2])
	if text.contains("%d"):
		text = text % DeepCreatures.trait_value(foe, name, 50)
	## The move that pinned it names it (a Null Shade's Dampen is a Hush by another name).
	for move in Look.moves(foe):
		for effect in move.get("effects", []):
			if str(effect.get("kind", "")) == "pin_trait" and str(effect.get("trait", "")) == name and name != "reroll_all":
				title = str(move.get("name", title))
	return EffectChips.entry("pinned_" + name, str(said[0]), "", false, title, text, Color("c8a8ff"), 1, "trait")

func _sync_pills(foe: Dictionary) -> void:
	## One grey pill a move on its faces, in the order its dice show them, then a pill for each
	## match its faces make together (its marks side by side, edged violet).
	var faces: Array = Look.distinct(foe)
	var matched: Array = Look.matches(foe)
	var entries: Array = []
	for entry in faces:
		var move: Dictionary = Look.move_of(foe, str(entry.move))
		entries.append({"name": str(entry.move), "mark": str(entry.mark), "kind": str(entry.kind), "value": Look.number(foe, move), "count": int(entry.count), "move": move})
	var key: String = str(entries.map(func(e: Dictionary) -> String: return "%s:%s:%s:%s" % [e.name, e.mark, e.value, e.count])) + str(matched.map(func(m: Dictionary) -> String: return str(m.get("name", "")) + Look.number(foe, m)))
	key += str(_warden)
	if key == _pills_key:
		return
	_pills_key = key
	DeepUi.clear(_pills)
	_pill_of.clear()
	## A Warden's pills say their names if the row stays narrow enough to read at a glance.
	var named: bool = false
	if _warden:
		named = _row_width(entries, matched, true) <= NAMED_MOST
	var faces_total: int = 0
	for die_entry in Look.face_dice(foe):
		faces_total += die_entry.die.get("faces", []).size()
	for entry in entries:
		var pill := _pill(entry.mark, entry.kind, (str(entry.name) + (" " if not str(entry.value).is_empty() else "")) if named else "", str(entry.value))
		var move: Dictionary = entry.move
		var share: String = "%d of %d faces" % [int(entry.count), faces_total]
		Tips.attach(pill, func() -> Control: return Plates.words(str(move.get("name", "")), Look.text(_foe, move), share, Look.ink(str(entry.kind))), {"tone": Look.ink(str(entry.kind))})
		_pill_of[str(entry.name)] = pill
	for move in matched:
		## Its faces' marks side by side: the one face as many times as it must land, or each
		## face it needs once.
		var marks: Array = []
		for face in Look.match_faces(move):
			var on: Dictionary = Look.move_of(foe, str(face))
			marks.append(str(on.get("mark", move.get("mark", ""))))
		var need: int = int(move.get("trigger", {}).get("count", 0))
		if need > 1 and not marks.is_empty():
			marks = [marks[0]]
			for _again in range(mini(need, 3) - 1):
				marks.append(marks[0])
		if marks.is_empty():
			marks = [str(move.get("mark", ""))]
		var pill := _pill(str(marks[0]), Look.kind_of(move), str(move.get("name", "")) + " " if named else "", Look.number(foe, move), marks.slice(1, 3), true)
		var words: String = Look.text(foe, move)
		var note: String = Look.match_note(move)
		var tone: Color = Look.ink(Look.kind_of(move))
		Tips.attach(pill, func() -> Control: return Plates.words(str(move.get("name", "")), words, note, tone), {"tone": tone})
		_pill_of[str(move.get("name", ""))] = pill

func _row_width(entries: Array, matched: Array, named: bool) -> float:
	var font: Font = DeepUi.bold_font()
	var size: int = DeepUi.readable(11)
	var wide: float = 0.0
	for entry in entries:
		var words: String = (str(entry.name) + " " if named else "") + str(entry.value)
		wide += 12.0 + 18.0 + (font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 4.0 if not words.strip_edges().is_empty() else 0.0) + 4.0
	for move in matched:
		var words: String = (str(move.get("name", "")) + " " if named else "") + Look.number(_foe, move)
		wide += 12.0 + 36.0 + font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 8.0
	return wide

func _pill(mark_name: String, kind: String, name_words: String, value: String, more_marks: Array = [], matched: bool = false) -> PanelContainer:
	## A grey pill: a move's mark in its kind's ink and its number (and on a Warden its name).
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := DeepUi.flat(Look.PILL_FILL, Look.MATCH_LINE if matched else Look.PILL_LINE, 5, 2, 2)
	style.content_margin_left = 6
	style.content_margin_right = 7
	pill.add_theme_stylebox_override("panel", style)
	_pills.add_child(pill)
	var row := DeepUi.hbox(pill, 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint: Color = Look.ink(kind)
	Look.mark(row, mark_name, 13, tint)
	for extra in more_marks:
		var also := Look.mark(row, str(extra), 13, tint)
		also.custom_minimum_size.x = 11
	var words: String = name_words + value
	if not words.strip_edges().is_empty():
		var said := DeepUi.label(row, words.strip_edges(), 11, DeepUi.PAPER)
		said.add_theme_font_override("font", DeepUi.bold_font())
	return pill

# --- the dice ------------------------------------------------------------------------------------

func _sync_dice(foe: Dictionary) -> void:
	## Its dice as solids: rebuilt only when a die is added, grows a size or has a face
	## re-etched; otherwise each is turned to the face it shows.
	var dice: Array = DeepCreatures.effective_dice(foe)
	var acting: bool = bool(foe.get("acting", false))
	var gone: int = int(foe.get("suppressed", 0)) if acting else int(foe.get("stolen_dice", 0))
	var key: String = str(dice.map(func(d: Dictionary) -> String: return "%s:%s" % [str(d.get("id", "")), str(d.get("shape", ""))]))
	if key != _dice_key:
		_dice_key = key
		_build_holders(dice)
	var hand: Array = foe.get("hand", []) if acting or str(foe.get("beat", "")) == "done" else []
	for index in range(mini(dice.size(), _holders.size())):
		var entry: Dictionary = _holders[index]
		var die: Dictionary = dice[index]
		var roll: Dictionary = {}
		for thrown in hand:
			if str(thrown.get("die_id", "")) == str(die.get("id", "")):
				roll = thrown
		if roll.is_empty():
			roll = rest_roll(die)
		_show_die(entry, die, roll, false)
		(entry.holder as Control).modulate.a = 0.3 if index >= dice.size() - gone else 1.0

static func rest_roll(die: Dictionary) -> Dictionary:
	## The face a die shows between throws: the first face of the move most of its faces carry
	## (its plain attack, nearly always), so a die at rest says what it mostly does.
	var faces: Array = die.get("faces", [])
	var counts: Dictionary = {}
	for face in faces:
		if face is Dictionary:
			counts[str(face.get("move", ""))] = int(counts.get(str(face.get("move", "")), 0)) + 1
	var best: int = 0
	for at in range(faces.size()):
		if faces[at] is Dictionary and int(counts.get(str(faces[at].get("move", "")), 0)) > int(counts.get(str(faces[best].get("move", "")), 0) if faces[best] is Dictionary else 0):
			best = at
	var value: int = int(faces[best].get("value", best + 1)) if best < faces.size() and faces[best] is Dictionary else best + 1
	return {"die_id": str(die.get("id", "")), "face": best, "value": value, "turn_tag": "rest"}

static func _token(roll: Dictionary) -> String:
	## The roll as DiceView tells one throw from another.
	return "%s#%s#%s#%s" % [str(roll.get("die_id", "")), str(roll.get("rerolls", -1)), str(roll.get("face", -1)), str(roll.get("turn_tag", ""))]

func _show_die(entry: Dictionary, die: Dictionary, roll: Dictionary, thrown: bool) -> void:
	var view: DiceView = entry.view
	var token: String = _token(roll)
	if token == str(entry.token) and not thrown:
		## The same throw: only the solid's faces may have changed (a face re-etched).
		view.configure(die, roll, false, false, Look.ink("attack"))
		return
	if thrown and token == str(entry.token):
		## Already shown landed (the state got here before the throw did): it is thrown anyway.
		view.configure(die, rest_roll(die).merged({"turn_tag": "again"}, true), false, false, Look.ink("attack"))
	entry.token = token
	view.configure(die, roll, false, false, Look.ink("attack"))
	if not thrown:
		view.settle_immediately()

func _build_holders(dice: Array) -> void:
	## A solid a die. A die still here at the same size keeps its solid (and what it shows, and
	## whether it is grown) when another is added or one goes, and the stack keeps its order: a
	## die still here keeps its place in it, a new one goes in at the back.
	if _swap != null and _swap.is_valid():
		_swap.kill()
	_swap = null
	_spots = dice_spots(dice.size(), panel_height())
	var kept: Dictionary = {}
	var was: Dictionary = {}
	for entry in _holders:
		kept[str(entry.id)] = entry
		was[str(entry.id)] = int(entry.get("place", 0))
	var ranked: Array = range(dice.size())
	ranked.sort_custom(func(a: int, b: int) -> bool:
		var at_a: int = int(was.get(str(dice[a].get("id", "")), 1000 + a))
		var at_b: int = int(was.get(str(dice[b].get("id", "")), 1000 + b))
		return at_a < at_b if at_a != at_b else a < b)
	var places: Array = []
	places.resize(dice.size())
	for place in range(ranked.size()):
		places[ranked[place]] = place
	var rolling_id: String = str(_holders[_rolling].id) if _rolling >= 0 and _rolling < _holders.size() else ""
	var built: Array = []
	for index in range(dice.size()):
		var place: int = int(places[index])
		var spot: Array = _spots[place]
		var edge: float = float(spot[1])
		var id: String = str(dice[index].get("id", ""))
		var old: Variant = kept.get(id, null)
		if old != null and is_equal_approx(float(old.edge), edge) and str(old.get("shape", "")) == str(dice[index].get("shape", "")) and is_instance_valid(old.holder):
			(old.holder as Control).position = spot[0]
			old.place = place
			built.append(old)
			kept.erase(id)
			continue
		var made: Dictionary = _holder(id, str(dice[index].get("shape", "")), edge, spot[0])
		made.place = place
		built.append(made)
	for id in kept:
		if is_instance_valid(kept[id].holder):
			(kept[id].holder as Control).queue_free()
	_holders = built
	_rolling = -1
	for index in range(_holders.size()):
		if str(_holders[index].id) == rolling_id:
			_rolling = index
			(_holders[index].view as Control).scale = Vector2.ONE
	_stack()
	_inset = dice_inset(_spots)
	_style()

func _stack() -> void:
	## Drawn back to front, the one being thrown over them all.
	var ranked: Array = range(_holders.size())
	ranked.sort_custom(func(a: int, b: int) -> bool: return int(_holders[a].place) > int(_holders[b].place))
	for index in ranked:
		_dice.move_child(_holders[index].holder, -1)
	if _rolling >= 0 and _rolling < _holders.size():
		_dice.move_child(_holders[_rolling].holder, -1)

func _place_dice() -> void:
	## Each die where its place in the stack stands.
	for entry in _holders:
		var place: int = int(entry.get("place", 0))
		if place < _spots.size() and is_instance_valid(entry.holder):
			(entry.holder as Control).position = _spots[place][0]

func _swapping() -> bool:
	return _swap != null and _swap.is_valid() and _swap.is_running()

func place_of(index: int) -> int:
	## Where a die stands in the stack, 0 at the front.
	return int(_holders[index].get("place", 0)) if index >= 0 and index < _holders.size() else -1

func _bring_forward(index: int) -> void:
	## A die thrown from behind the stack swaps round to the front, passing over the others,
	## while the one that stood there drops back under them to the place it left.
	var place: int = int(_holders[index].place)
	if place == 0 or place >= _spots.size():
		_stack()
		return
	var other: int = -1
	for at in range(_holders.size()):
		if int(_holders[at].place) == 0:
			other = at
	_holders[index].place = 0
	if other >= 0:
		_holders[other].place = place
	_stack()
	if _swap != null and _swap.is_valid():
		_swap.kill()
	_swap = null
	if DeepUi.headless() or not is_inside_tree() or ScreenFx.calm:
		_place_dice()
		return
	var lift: float = float(_holders[index].edge) * 0.3
	_swap = create_tween().set_parallel(true)
	_hop(_swap, _holders[index].holder, _spots[0][0], -lift)
	if other >= 0:
		_hop(_swap, _holders[other].holder, _spots[place][0], lift * 0.5)
	_swap.chain().tween_callback(_place_dice)

static func _hop(tween: Tween, node: Control, to: Vector2, lift: float) -> void:
	## Across in one ease and up (or down) and back in another, so it goes round in an arc.
	var mid: float = (minf(node.position.y, to.y) if lift < 0.0 else maxf(node.position.y, to.y)) + lift
	tween.tween_property(node, "position:x", to.x, SWAP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", mid, SWAP * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:y", to.y, SWAP * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(SWAP * 0.5)

func _holder(id: String, shape: String, edge: float, at: Vector2) -> Dictionary:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(edge, edge)
	holder.position = at
	_dice.add_child(holder)
	## Drawn at its thrown size and shown smaller at rest, so the solid is as sharp grown as
	## it is standing in. At rest it fills its place; it grows about its right edge and its
	## middle (the point of the picture over the place's right edge, half way down).
	var shown: float = edge * FRAME
	var big: float = roundf(shown * GROW)
	var view := DiceView.new()
	view.live = true
	view.tilt = true
	view.hush = 0.8
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.size = Vector2(big, big)
	view.custom_minimum_size = view.size
	view.pivot_offset = Vector2((edge + shown) * 0.5 * GROW, big * 0.5)
	view.position = Vector2(edge, edge * 0.5) - view.pivot_offset
	view.scale = Vector2.ONE / GROW
	holder.add_child(view)
	return {"holder": holder, "view": view, "id": id, "shape": shape, "edge": edge, "token": ""}

static func dice_spots(count: int, tall: float) -> Array:
	## Where each place in the stack stands over the tag's left end, [position, edge], the front
	## first: one die big and a little over the corner; more nearly as big, overlapped in a fan,
	## the front one at the right by the name and each behind it a step to the left and a little
	## higher, the last no further out past the tag's edge than the screen keeps clear
	## (`TAG_REACH`). The more dice, the smaller each and the closer the steps.
	var out: Array = []
	if count <= 0:
		return out
	if count == 1:
		out.append([Vector2(-8.0, (tall - 62.0) * 0.5 - 2.0), 62.0])
		return out
	var edge: float = maxf(46.0, 60.0 - 2.0 * float(count))
	var step: float = edge * maxf(0.26, 0.53 - 0.04 * float(count))
	var rise: float = minf(5.0, 12.0 / float(count - 1))
	var front := Vector2(-12.0 + step * float(count - 1), (tall - edge) * 0.5 + rise * float(count - 1) * 0.5 - 1.0)
	for place in range(count):
		out.append([front - Vector2(step, rise) * float(place), edge])
	return out

static func dice_inset(spots: Array) -> float:
	var right: float = 0.0
	for spot in spots:
		right = maxf(right, (spot[0] as Vector2).x + float(spot[1]))
	return maxf(INSET, right + 4.0)

func panel_height() -> float:
	return panel.get_combined_minimum_size().y

func die_mark(index: int) -> Control:
	## A die on the tag, for a count to point at.
	return _holders[index].holder if index >= 0 and index < _holders.size() and is_instance_valid(_holders[index].holder) else null

func die_view(index: int) -> DiceView:
	return _holders[index].view if index >= 0 and index < _holders.size() and is_instance_valid(_holders[index].view) else null

func dice_count() -> int:
	return _holders.size()

# --- the throw -----------------------------------------------------------------------------------

func roll(event: Dictionary) -> void:
	## The die it throws grows on the tag, tumbles and lands; what it landed on comes up over it.
	var index: int = int(event.get("roll_index", 0))
	if index < 0 or index >= _holders.size():
		return
	if _rolling >= 0 and _rolling != index:
		_shrink(_rolling)
	_rolling = index
	var entry: Dictionary = _holders[index]
	var view: DiceView = entry.view
	_bring_forward(index)
	_result.visible = false
	var spin: float = maxf(0.3, float(event.get("duration", 1.1)) - 0.28)
	view.spin_seconds = spin
	view.suspense = bool(event.get("suspense", false))
	view.suspense_scale = CameraRig.comfort
	_show_die(entry, event.get("die", {}), event.get("roll", {}), true)
	if _landing != null and _landing.is_valid():
		_landing.kill()
	if DeepUi.headless() or not is_inside_tree():
		view.scale = Vector2.ONE
		_land(event)
		return
	var grow := create_tween()
	grow.tween_property(view, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_landing = create_tween()
	if view.suspense:
		## Rising clacks on scaled time, so the fight's speed cannot pull them apart.
		for step in range(5):
			var pitch: float = 0.8 + float(step) * 0.14
			_landing.tween_callback(func() -> void: DeepAudio.from(view, "die_tumble", {"pitch": pitch, "volume": 0.3 + pitch * 0.15, "gap": 0.0}))
			_landing.tween_interval(spin / 5.0)
	else:
		_landing.tween_interval(spin)
	_landing.tween_callback(_land.bind(event))

func _land(event: Dictionary) -> void:
	var roll: Dictionary = event.get("roll", {})
	var move: Dictionary = Look.move_of(_foe, str(roll.get("move", "")))
	if move.is_empty():
		move = {"name": str(roll.get("move", "")), "kind": str(roll.get("move_kind", "attack")), "mark": str(roll.get("mark", ""))}
	var kind: String = Look.kind_of(move)
	show_result(str(move.get("mark", roll.get("mark", ""))), kind, Look.result_words(_foe, move, _party))
	var index: int = int(event.get("roll_index", 0))
	if index >= 0 and index < _holders.size() and not DeepUi.headless():
		## It jumps as it lands (not the tray's pop: its ring would be drawn round the whole
		## picture here, far wider than the solid).
		var view: DiceView = _holders[index].view
		var holder: Control = _holders[index].holder
		DeepUi.pulse(holder, 1.1, 0.25)
		if not ScreenFx.calm:
			DeepUi.burst(self, holder.position + Vector2(holder.size.x * (1.0 - DIE_FILL * GROW * 0.5), holder.size.y * 0.5), Look.EDGE.get(kind, DeepUi.BAD), 12, 95.0, 0.25)
		DeepAudio.from(view, "hit_crit", {"volume": 0.4, "pitch": 0.95})
	var pill: Control = _pill_of.get(str(move.get("name", "")), null)
	if pill != null and is_instance_valid(pill):
		DeepUi.pulse(pill, 1.2, 0.3)

func show_result(mark_name: String, kind: String, words: String) -> void:
	## The landed face over the die: its mark and what it does, edged in the colour of it.
	_result_mark.texture = Look.mark_texture(mark_name)
	_result_mark.modulate = Look.ink(kind)
	_result_label.text = words
	var style := DeepUi.capsule(_result, Color(0.067, 0.078, 0.114, 0.96), Look.EDGE.get(kind, DeepUi.BAD), 2, 10, 3)
	DeepUi.drop_shadow(style, 3)
	_result.add_theme_stylebox_override("panel", style)
	_result.visible = true
	_result.modulate.a = 1.0
	_place_result()
	if not DeepUi.headless() and is_inside_tree():
		DeepUi.pop_in(_result, 0.0, 0.7, 0.22)

func say(words: String) -> void:
	## The result pill's words, told more once the move has landed (a per-reroll total).
	if _result.visible:
		_result_label.text = words
		_place_result()

func result_words() -> String:
	return _result_label.text if _result.visible else ""

func _place_result() -> void:
	_result.reset_size()
	var index: int = clampi(_rolling, 0, maxi(0, _holders.size() - 1))
	if _holders.is_empty():
		_result.position = Vector2(-_result.size.x * 0.5, -_result.size.y - 6.0)
		return
	## Where the die is going, not where it is: it may still be swapping round to the front.
	var place: int = place_of(index)
	var at: Vector2 = _spots[place][0] if place >= 0 and place < _spots.size() else (_holders[index].holder as Control).position
	var edge: float = float(_holders[index].edge)
	## The grown die: its right edge where it was, DIE_FILL of its place times GROW across.
	var grown: float = edge * DIE_FILL * GROW
	var centre_x: float = at.x + edge * (1.0 + DIE_FILL) * 0.5 - grown * 0.5
	var top: float = at.y + edge * 0.5 - grown * 0.5
	_result.position = Vector2(centre_x - _result.size.x * 0.5, top - _result.size.y - 2.0)

func settle() -> void:
	## Its action is over: the grown die goes back into the tag, still showing what it landed
	## on, and the pill over it goes.
	if _rolling >= 0:
		_shrink(_rolling)
	_rolling = -1
	if _landing != null and _landing.is_valid():
		_landing.kill()
	if not _result.visible:
		return
	if DeepUi.headless() or not is_inside_tree():
		_result.visible = false
		return
	var out := create_tween()
	out.tween_property(_result, "modulate:a", 0.0, 0.25)
	out.tween_callback(func() -> void: _result.visible = false)

func _shrink(index: int) -> void:
	if index < 0 or index >= _holders.size():
		return
	var view: DiceView = _holders[index].view
	if not is_instance_valid(view):
		return
	if DeepUi.headless() or not is_inside_tree():
		view.scale = Vector2.ONE / GROW
		return
	create_tween().tween_property(view, "scale", Vector2.ONE / GROW, 0.25).set_trans(Tween.TRANS_SINE)

func rolling() -> int:
	return _rolling

func grown(index: int) -> bool:
	var view: DiceView = die_view(index)
	return view != null and view.scale.x > 1.0 / GROW + 0.05

func power(move_name: String) -> void:
	## A move being acted out: its pill jumps.
	var pill: Control = _pill_of.get(move_name, null)
	if pill != null and is_instance_valid(pill):
		DeepUi.pulse(pill, 1.18, 0.3)

func impact(move_name: String) -> void:
	var pill: Control = _pill_of.get(move_name, null)
	if pill != null and is_instance_valid(pill):
		DeepUi.pulse(pill, 1.08, 0.25)
	else:
		DeepUi.pulse(self, 1.03, 0.3)

func etched(changes: Array) -> void:
	## A face re-etched, or a die grown: the solid it happened on hops in the new move's colour.
	for change in changes:
		var at: int = int(change.get("die", -1))
		var view: DiceView = die_view(at)
		if view != null and not DeepUi.headless():
			var holder: Control = die_mark(at)
			DeepUi.pulse(holder, 1.2, 0.35)
			DeepUi.burst(self, holder.position + holder.size * 0.5, Look.EDGE.get(str(change.get("kind", "ready")), DeepUi.ACCENT), 14, 90.0, 0.4)
		var pill: Control = _pill_of.get(str(change.get("to", "")), null)
		if pill != null and is_instance_valid(pill):
			DeepUi.pulse(pill, 1.25, 0.4)

func pill_of(move_name: String) -> Control:
	return _pill_of.get(move_name, null)

func pill_count() -> int:
	return _pills.get_child_count()

func chips() -> EffectChips.Row:
	return _chips

# --- laying it out -------------------------------------------------------------------------------

var _laying: bool = false

func _relayout() -> void:
	## The panel as wide as its pills need (a Warden's at least WARDEN_WIDTH), the dice over its
	## left end, the block chip over its top right corner, the chips under it.
	if _laying:
		return
	_laying = true
	## As wide as its pills or its name, whichever is wider: a name is never cut short.
	var name_size: int = _name.get_theme_font_size(&"font_size")
	var named: float = DeepUi.bold_font().get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x + 4.0
	var wide: float = maxf(WARDEN_WIDTH if _warden else MIN_WIDTH, _inset + maxf(_pills.get_combined_minimum_size().x, named) + 12.0)
	_name.custom_minimum_size.x = 0.0
	_bar.custom_minimum_size.x = maxf(40.0, wide - _inset - 10.0)
	panel.custom_minimum_size.x = wide
	panel.reset_size()
	panel.position = Vector2.ZERO
	var tall: float = panel.size.y
	custom_minimum_size = panel.size
	size = panel.size
	_spots = dice_spots(_holders.size(), tall)
	if not _swapping():
		_place_dice()
	_block.reset_size()
	_block.position = Vector2(size.x - _block.size.x - 10.0, -_block.size.y * 0.5 - 2.0)
	_chips.position = Vector2(_inset, tall + 3.0)
	_chips.custom_minimum_size.x = maxf(60.0, size.x - _inset)
	_chips.reset_size()
	if _result.visible:
		_place_result()
	_laying = false

func chips_height() -> float:
	return _chips.get_combined_minimum_size().y if _chips.get_child_count() > 0 else 0.0

func standing_height() -> float:
	## The tag and the chips under it.
	var under: float = chips_height()
	return size.y + (under + 3.0 if under > 0.0 else 0.0)

func fade(gone: Callable = Callable()) -> void:
	## Out, and then freed: `gone` is told first, so the screen can drop it from its book.
	fading = true
	_result.visible = false
	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		visible = false
		if gone.is_valid():
			gone.call()
		queue_free())

func _get_tooltip(_at: Vector2) -> String:
	return ""

# --- its health ----------------------------------------------------------------------------------

class HealthBar extends Control:
	## Its health: the fill eases to its share and a pale ghost trails what it lost; its block
	## hatched in blue over the end of the bar; a blow this hand would land hatched red at the
	## end of the fill; the numbers in the middle.
	var thick: bool = false:
		set(value):
			thick = value
			update_minimum_size()
	var ratio: float = 1.0
	var block: float = 0.0
	var text: String = ""
	var preview: float = 0.0:
		set(value):
			if not is_equal_approx(value, preview):
				preview = value
				set_process(true)
				queue_redraw()
	var _shown: float = -1.0
	var _ghost: float = 1.0
	var _clock: float = 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _get_minimum_size() -> Vector2:
		return Vector2(40.0, float(_font_size()) + (5.0 if thick else 3.0))
	func _font_size() -> int:
		return DeepUi.readable(10)
	func show_health(share: float, words: String, guard: float) -> void:
		share = clampf(share, 0.0, 1.0)
		if _shown < 0.0 or DeepUi.headless() or not is_inside_tree():
			_shown = share
			_ghost = share
		elif share > _ghost:
			_ghost = share
		ratio = share
		block = guard
		text = words
		set_process(true)
		queue_redraw()
	func _process(delta: float) -> void:
		_clock += delta
		var settled: bool = true
		if not is_equal_approx(_shown, ratio):
			_shown = move_toward(_shown, ratio, maxf(0.4, absf(ratio - _shown) * 6.0) * delta)
			settled = false
		if _ghost > _shown:
			if _clock > 0.35:
				_ghost = move_toward(_ghost, _shown, 0.55 * delta)
			settled = false
		else:
			_ghost = _shown
			_clock = 0.0
		if preview > 0.0:
			settled = false
		queue_redraw()
		if settled:
			_clock = 0.0
			set_process(false)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("4a2222"))
		if _ghost > _shown:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _ghost, size.y)), Color(1, 0.92, 0.8, 0.5))
		if _shown > 0.001:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _shown, size.y)), Color("e8665a"))
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _shown, size.y * 0.45)), Color("ff8f80"))
		if preview > 0.0 and _shown > 0.001:
			var cut: float = minf(preview, _shown)
			var pulse: float = 0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
			var taking := Rect2(Vector2(size.x * (_shown - cut), 0), Vector2(size.x * cut, size.y))
			draw_rect(taking, Color(1.0, 0.35, 0.3, pulse * 0.5))
			_hatch(taking, Color(1.0, 0.85, 0.8, pulse), Color(0, 0, 0, 0))
		if block > 0.0:
			var guard := Rect2(Vector2(size.x * (1.0 - block), 0), Vector2(size.x * block, size.y))
			_hatch(guard, Color("6fa8ff"), Color("3e6fb8"))
		draw_rect(r, Color(0, 0, 0, 0.55), false, 1.0)
		if not text.is_empty():
			var font: Font = DeepUi.bold_font()
			var font_size: int = _font_size()
			var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var at := Vector2((size.x - measured.x) * 0.5, size.y * 0.5 + font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.5)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.75))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	func _hatch(rect: Rect2, light: Color, dark: Color) -> void:
		## Stripes at a slant across a rect, clipped to it: light and dark in turn.
		if rect.size.x <= 0.5:
			return
		if dark.a > 0.0:
			draw_rect(rect, dark)
		var h: float = rect.size.y
		var x: float = rect.position.x - h
		while x < rect.end.x:
			var a := Vector2(x, rect.end.y)
			var b := Vector2(x + h, rect.position.y)
			var t0: float = maxf(0.0, (rect.position.x - x) / h)
			var t1: float = minf(1.0, (rect.end.x - x) / h)
			if t1 > t0:
				draw_line(a.lerp(b, t0), a.lerp(b, t1), light, 3.0, true)
			x += 6.0
