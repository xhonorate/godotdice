extends Control
## Right-click on a creature (the plates rethink, the owner's rounds four, five and eleven):
## the room dims and a window opens with its die, large enough to turn over by hand, standing
## vertically centred beside the list of what each of its faces does. Pointing at a row turns
## that face to the front. A creature with several dice has a button a die under it. Esc, or
## a click outside the window, closes it; its foot opens the creature's Bestiary page.

const DiceView = preload("res://view/dice/dice_view.gd")
const Look = preload("res://view/battle/creature_look.gd")
const Tag = preload("res://view/battle/creature_tag.gd")
const Inspector = preload("res://view/inspect/inspector.gd")

signal closed

const WIDTH: float = 820.0
const DIE_EDGE: float = 260.0
const PICTURE: float = 1.35
const TOP: float = 80.0

var foe: Dictionary = {}
var battle: Dictionary = {}
var die_index: int = 0
var _window: PanelContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _view: DiceView
var _tabs: HBoxContainer
var _list: VBoxContainer
var _cap: Label
var _closing: bool = false

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	var dim := ColorRect.new()
	dim.color = Color(0.016, 0.024, 0.047, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_window = PanelContainer.new()
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := DeepUi.ledger(Color(0.067, 0.078, 0.114, 0.98), DeepUi.ACCENT, 12, 16, 2, 6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	_window.add_theme_stylebox_override("panel", style)
	_window.custom_minimum_size.x = WIDTH
	add_child(_window)
	var columns := DeepUi.hbox(_window, 20)
	columns.mouse_filter = Control.MOUSE_FILTER_PASS
	_left = DeepUi.vbox(columns, 8)
	_left.custom_minimum_size.x = 300
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left.mouse_filter = Control.MOUSE_FILTER_PASS
	## The solid is drawn with room round it, so its picture is larger than its place for the
	## die itself to fill the place.
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(DIE_EDGE, DIE_EDGE)
	stand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stand.mouse_filter = Control.MOUSE_FILTER_PASS
	_left.add_child(stand)
	_view = DiceView.new()
	var drawn: float = roundf(DIE_EDGE * PICTURE)
	_view.custom_minimum_size = Vector2(drawn, drawn)
	_view.size = _view.custom_minimum_size
	_view.position = Vector2.ONE * (DIE_EDGE - drawn) * 0.5
	_view.interactive = true
	_view.tilt = true
	stand.add_child(_view)
	var drag := DeepUi.label(_left, "DRAG TO TURN IT OVER", 10, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	drag.add_theme_font_override("font", DeepUi.bold_font())
	_tabs = DeepUi.hbox(_left, 6)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.mouse_filter = Control.MOUSE_FILTER_PASS
	_right = DeepUi.vbox(columns, 6)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right.mouse_filter = Control.MOUSE_FILTER_PASS
	var top_row := DeepUi.hbox(_right, 8)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap = DeepUi.label(top_row, "", 10, DeepUi.MUTED)
	_cap.add_theme_font_override("font", DeepUi.bold_font())
	_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := DeepUi.label(top_row, "Esc · click outside to close", 11, DeepUi.MUTED)
	close.add_theme_font_override("font", DeepUi.bold_font())
	var title := DeepUi.label(_right, "WHAT EACH FACE DOES", 18, DeepUi.PAPER)
	title.add_theme_font_override("font", DeepUi.bold_font())
	_list = DeepUi.vbox(_right, 5)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	var foot := Button.new()
	foot.text = "Open its Bestiary page"
	foot.flat = true
	foot.alignment = HORIZONTAL_ALIGNMENT_LEFT
	foot.focus_mode = Control.FOCUS_NONE
	foot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	DeepUi.set_text_size(foot, 11)
	foot.add_theme_color_override("font_color", DeepUi.MUTED)
	foot.add_theme_color_override("font_hover_color", DeepUi.ACCENT_HI)
	foot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	foot.pressed.connect(_bestiary)
	_right.add_child(foot)
	resized.connect(_place)
	_window.resized.connect(_place)

func open(unit: Dictionary, fight: Dictionary, index: int = 0) -> void:
	foe = unit
	battle = fight
	die_index = clampi(index, 0, maxi(0, Look.face_dice(foe).size() - 1))
	_build()
	if not DeepUi.headless() and is_inside_tree():
		DeepAudio.play("ui_open", {"volume": 0.55})
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.14)

func _build() -> void:
	var dice: Array = Look.face_dice(foe)
	if dice.is_empty():
		return
	var entry: Dictionary = dice[die_index]
	var die: Dictionary = entry.die
	var label: String = str(die.get("label", ""))
	_cap.text = ("%s's %s · %s · %d faces" % [str(foe.get("name", "")), label if not label.is_empty() else "die", str(die.get("shape", "D6")).to_lower(), die.get("faces", []).size()]).to_upper()
	_view.configure(die, Tag.rest_roll(die), false, false, DeepUi.ACCENT)
	_view.enable_interaction()
	DeepUi.clear(_tabs)
	_tabs.visible = dice.size() > 1
	if dice.size() > 1:
		for at in range(dice.size()):
			var other: Dictionary = dice[at].die
			var named: String = str(other.get("label", ""))
			var button := Button.new()
			button.text = ("%s %s" % [named, str(other.get("shape", "D6")).to_lower()]).strip_edges() if not named.is_empty() else "die %d · %s" % [at + 1, str(other.get("shape", "D6")).to_lower()]
			button.focus_mode = Control.FOCUS_NONE
			DeepUi.set_text_size(button, 12)
			if at == die_index:
				DeepUi.ledger_primary(button)
			else:
				DeepUi.ledger_button(button, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 4)
			button.pressed.connect(func() -> void:
				die_index = at
				_build())
			_tabs.add_child(button)
	DeepUi.clear(_list)
	for move_entry in entry.moves:
		var move: Dictionary = Look.move_of(foe, str(move_entry.move))
		if move.is_empty():
			move = {"name": str(move_entry.move), "mark": str(move_entry.mark), "kind": str(move_entry.kind)}
		var row: Control = Look.row(_list, foe, move, int(move_entry.count), die.get("faces", []).size())
		## Pointing at a row turns its face to the front.
		var face: int = _first_face(die, str(move_entry.move))
		row.mouse_entered.connect(func() -> void: _view.focus_face(face))
	## What its faces make together, when this die has a part in it; what the fight calls it to
	## do (as it comes up, as it dies) and what waits for a face; and what it always is.
	for move in Look.matches(foe):
		var faces: Array = Look.match_faces(move)
		if entry.moves.any(func(m: Dictionary) -> bool: return faces.has(str(m.move))):
			Look.row(_list, foe, move, 0, 0, Look.match_note(move))
	for extra in Look.extras(foe):
		Look.row(_list, foe, extra.move, 0, 0, str(extra.note))
	var traits: Array = Look.traits(foe)
	if not traits.is_empty():
		DeepUi.rule(_list, Look.PILL_LINE).custom_minimum_size.y = 2
		for chip in traits:
			Look.trait_row(_list, foe, chip)
	_place.call_deferred()

static func _first_face(die: Dictionary, move_name: String) -> int:
	var faces: Array = die.get("faces", [])
	for at in range(faces.size()):
		if faces[at] is Dictionary and str(faces[at].get("move", "")) == move_name:
			return at
	return 0

func _place() -> void:
	## Centred across the room, near its top.
	_window.reset_size()
	_window.position = Vector2(roundf((size.x - _window.size.x) * 0.5), minf(TOP, maxf(8.0, (size.y - _window.size.y) * 0.5)))

func _process(_delta: float) -> void:
	## Rich text stands its row tall until it has its width: the window shrinks back once the
	## words are laid out.
	if _window.size.y > _window.get_combined_minimum_size().y + 0.5:
		_place()

func _gui_input(event: InputEvent) -> void:
	## A click outside the window closes it.
	if event is InputEventMouseButton and event.pressed and not _window.get_global_rect().has_point(event.global_position):
		close()
		accept_event()

func _input(event: InputEvent) -> void:
	## While it is up, Esc is its own.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	if DeepUi.headless() or not is_inside_tree():
		queue_free()
		return
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.12)
	out.tween_callback(queue_free)

func _bestiary() -> void:
	var looked: Dictionary = foe
	var fight: Dictionary = battle
	close()
	Inspector.creature(looked, fight)

func rows() -> int:
	return _list.get_child_count()

func die_view() -> DiceView:
	return _view
