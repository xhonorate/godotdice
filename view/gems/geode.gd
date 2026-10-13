extends CanvasLayer
## A Geode cracked on the bench, or a contract's five stones made into one (docs/GOLD.md §3.3).
##
## The stone a Geode holds was rolled when the shelf was stocked and is on the tray, already
## read, by the time this opens: everything here is the showing, and skipping it loses nothing.
##
## Three blows open a Geode. The first leaves a hairline and a puff of grit; the second runs the
## crack through and lets light out (more light the better the stone inside); the third splits
## it, the halves fall away, and the hollow is lit in the color of the stone's grade. The stone
## rises out of it into a ring of rays, its grade is called, and it is read out line by line,
## weighed against the one of its skill already kept. The choice is made right there: keep it,
## sell it or turn it in, or leave it waiting in the vault.
##
## A contract plays the same ending from another start (`fuse`): five stones circle in to the
## middle of the bench and come out as one.
##
## A click or Space strikes; held Space strikes all three; Escape skips to the stone's card, and
## at the end takes the gentlest way out (the stone waits in the vault, unappraised).

const GemView = preload("res://view/gems/gem_view.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Appraisal = preload("res://view/gems/appraisal.gd")
const Inspector = preload("res://view/inspect/inspector.gd")

const RARITIES: Array = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY", "MYTHIC"]
## How long each line of the sheet holds before the next is read.
const PAUSES: Dictionary = {"name": 0.55, "carat": 0.45, "cut": 0.4, "clarity": 0.45, "inclusions": 0.45,
	"inclusion": 0.6, "grade": 0.8, "worth": 0.5, "compare": 0.5}
const STAGE := Vector2(560, 420)

static var _open: CanvasLayer = null

var geode: Dictionary = {}
var given: Array = []
var stone: Dictionary = {}
var owned: Dictionary = {}
## Each a choice: {label, glyph, tone, caption, call, primary, dismiss}.
var actions: Array = []
var mode: String = "geode"
var new_skill: bool = false
var wanted: String = ""
var closed: Callable = Callable()

var _root: Control
var _dim: ColorRect
var _rays: Control
var _title: Label
var _subtitle: Label
var _stage: Control
## What is on the stage, drawn shifted to the middle of the screen while the card beside it
## is still hidden, and slid back into its place as the card comes in.
var _slide: Control
var _art: Art
var _swirl: Swirl
var _view: Control
var _lamp: TextureRect
var _card: PanelContainer
var _card_style: StyleBoxFlat
var _sheet: Control
var _skip: Label
var _choices: Control
var _flash: ColorRect
var _tone: Color = DeepUi.ACCENT
var _tier_tone: Color = DeepUi.ACCENT
var _tweens: Array = []
var _blows: int = 0
var _phase: String = "ready"
var _done: bool = false
var _closing: bool = false
var _held: float = 0.0

static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)

static func open(shelf_geode: Dictionary, made: Dictionary, opts: Dictionary = {}, when_closed: Callable = Callable()) -> CanvasLayer:
	return _show("geode", shelf_geode, [], made, opts, when_closed)

static func fuse(inputs: Array, made: Dictionary, opts: Dictionary = {}, when_closed: Callable = Callable()) -> CanvasLayer:
	return _show("contract", {}, inputs, made, opts, when_closed)

static func _show(kind: String, shelf_geode: Dictionary, inputs: Array, made: Dictionary, opts: Dictionary, when_closed: Callable) -> CanvasLayer:
	if DisplayServer.get_name() == "headless":
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if is_open():
		_open.queue_free()
	Inspector.close()
	var made_layer: CanvasLayer = load("res://view/gems/geode.gd").new()
	tree.root.add_child(made_layer)
	made_layer.set("closed", when_closed)
	made_layer.call("build", kind, shelf_geode, inputs, made, opts)
	made_layer.call("play")
	_open = made_layer
	return made_layer

# --- building -------------------------------------------------------------------------------------

func build(kind: String, shelf_geode: Dictionary, inputs: Array, made: Dictionary, opts: Dictionary = {}) -> void:
	## Everything the ceremony will show, laid out from the start and hidden, so nothing moves
	## as it is revealed. `finish()` shows it all at once; `play()` plays it out.
	layer = 62
	mode = kind
	geode = shelf_geode
	given = inputs
	stone = made.duplicate(true)
	stone.appraised = true
	stone.inclusions_revealed = true
	owned = opts.get("owned", {})
	actions = opts.get("actions", [])
	new_skill = bool(opts.get("new_skill", owned.is_empty() and not DeepStone.is_birthstone(stone)))
	wanted = str(opts.get("wanted", ""))
	_tone = theme_tone(geode) if mode == "geode" else DeepUi.ACCENT
	_tier_tone = DeepUi.tier_color(str(DeepStone.grade(stone).tier))
	_root = Control.new()
	_root.theme = DeepUi.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.015, 0.94)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	_rays = Inspector.Rays.new(_tier_tone)
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.modulate.a = 0.0
	_root.add_child(_rays)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	var column := DeepUi.vbox(centre, 10)
	_title = DeepUi.title(column, geode_name(geode) if mode == "geode" else "The contract", 40, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("outline_size", 10)
	_subtitle = DeepUi.label(column, "Strike it. Three blows open it." if mode == "geode" else "Five stones go in; one comes out.", 16, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var row := DeepUi.hbox(column, 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stage.gui_input.connect(_stage_input)
	row.add_child(_stage)
	_slide = Control.new()
	_slide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_slide)
	_lamp = DeepUi.glow(_slide, _tier_tone, 0.0, 1.2)
	if mode == "geode":
		_art = Art.new(geode, _tone)
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slide.add_child(_art)
	else:
		_swirl = Swirl.new(given)
		_swirl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_swirl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slide.add_child(_swirl)
	_view = GemView.new()
	_view.anchor_left = 0.5
	_view.anchor_right = 0.5
	_view.anchor_top = 0.5
	_view.anchor_bottom = 0.5
	_view.offset_left = -130
	_view.offset_right = 130
	_view.offset_top = -150
	_view.offset_bottom = 110
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_drift(true)
	_view.set_spin(0.5)
	_view.configure(stone)
	_view.modulate.a = 0.0
	_slide.add_child(_view)
	## The card the stone is read out on, beside it once it is out.
	_card = PanelContainer.new()
	_card_style = DeepUi.raised(Color(0.045, 0.055, 0.09, 0.97), Color(_tier_tone, 0.7), 16, 18, 0.6)
	_card_style.set_border_width_all(2)
	_card.add_theme_stylebox_override("panel", _card_style)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.modulate.a = 0.0
	row.add_child(_card)
	var card_box := DeepUi.vbox(_card, 8)
	if new_skill:
		var fanfare := DeepUi.hbox(card_box, 8)
		DeepUi.pill(fanfare, "star", "New skill", StoneCard.PIP_NEW, 14)
		DeepUi.label(fanfare, "Your first %s" % DeepUi.skill_name(stone), 14, DeepUi.GOOD)
	if not wanted.is_empty():
		DeepUi.stat(card_box, "flag", wanted, DeepUi.GOOD, 13)
	_sheet = Appraisal.Sheet.new(stone, owned, {"skill_text": true, "owned_picture": false})
	card_box.add_child(_sheet)
	var foot := DeepUi.vbox(column, 6)
	foot.custom_minimum_size.y = 80
	_skip = DeepUi.label(foot, "Click the Geode or press Space to strike · Esc skips" if mode == "geode" else "Click or press Space to skip ahead", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_choices = Appraisal.choices(foot, actions, close)
	_choices.visible = false
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

# --- what the shelf and this page say about a Geode ---------------------------------------------------

static func geode_name(shelf_geode: Dictionary) -> String:
	var theme: String = str(shelf_geode.get("theme", ""))
	match str(shelf_geode.get("kind", "mine")):
		"color":
			return "%s Geode" % str(DeepContent.color(theme).get("name", theme.capitalize()))
		"featured":
			var found: Dictionary = {}
			for entry in DeepEconomy.featured_sets():
				if str(entry.get("key", "")) == theme:
					found = entry
			return str(found.get("name", "The week's Geode"))
	return "%s Geode" % DeepContent.mine_name(theme).trim_prefix("The ")

static func geode_line(shelf_geode: Dictionary) -> String:
	## One line under a Geode's name: where its stone comes from.
	var mine: String = DeepContent.mine_name(str(shelf_geode.get("mine", ""))).trim_prefix("The ")
	match str(shelf_geode.get("kind", "mine")):
		"color":
			var color: String = str(DeepContent.color(str(shelf_geode.get("theme", ""))).get("name", ""))
			return "%s stones only, from the %s's rock" % [color, mine]
		"featured":
			for entry in DeepEconomy.featured_sets():
				if str(entry.get("key", "")) == str(shelf_geode.get("theme", "")):
					return str(entry.get("text", ""))
	return "Anything the %s's rock can hold" % mine

static func theme_tone(shelf_geode: Dictionary) -> Color:
	## The color a Geode glows: its gem color, its mine's own color, or the accent for the
	## week's set.
	match str(shelf_geode.get("kind", "mine")):
		"color":
			return DeepUi.color(str(shelf_geode.get("theme", "")))
		"featured":
			return DeepUi.ACCENT_HI
	var palette: String = str(DeepContent.mine(str(shelf_geode.get("mine", ""))).get("palette", ""))
	return Color(palette).lightened(0.15) if not palette.is_empty() else DeepUi.ACCENT

static func rarity_tone(rarity: String) -> Color:
	return StoneCard._rarity_color(rarity)

static func rarity_shares(shelf_geode: Dictionary) -> Dictionary:
	## The share of a Geode's stones of each skill rarity, opals as Mythic.
	var odds: Dictionary = DeepEconomy.geode_odds(shelf_geode)
	var out: Dictionary = {}
	for entry in odds.get("skills", []):
		var rarity: String = str(DeepContent.skill(str(entry[0])).get("rarity", "COMMON"))
		out[rarity] = float(out.get(rarity, 0.0)) + float(entry[1])
	if float(odds.get("opal", 0.0)) > 0.0:
		out["MYTHIC"] = float(out.get("MYTHIC", 0.0)) + float(odds.opal)
	return out

static func percent(share: float) -> String:
	## A share as a whole percentage, and a sliver as "under 1%" rather than a misleading 0%.
	if share <= 0.0:
		return "0%"
	if share < 0.01:
		return "<1%"
	return "%d%%" % int(round(share * 100.0))

# --- playing it out ---------------------------------------------------------------------------------

func play() -> void:
	DeepAudio.play("ui_open", {"volume": 0.6})
	_slide.position.x = _centring()
	_dim.modulate.a = 0.0
	_track(create_tween()).tween_property(_dim, "modulate:a", 1.0, 0.22)
	DeepUi.pop_in(_stage, 0.0, 0.9, 0.38)
	if mode == "contract":
		_phase = "fusing"
		_swirl.begin()
		DeepAudio.play("altar_hum", {"volume": 0.7})
		var beat := _track(create_tween())
		beat.tween_interval(Swirl.LIFE)
		beat.tween_callback(_split)
		return
	_phase = "ready"
	_art.wobble = true

func _centring() -> float:
	## How far right of its place the stage is drawn to sit in the middle of the screen: half
	## the width of the card that will come in beside it, and the gap between them.
	var row: Control = _stage.get_parent() as Control
	var gap: float = float(row.get_theme_constant("separation")) if row != null else 0.0
	return (_card.get_combined_minimum_size().x + gap) * 0.5

func _heart() -> Vector2:
	## The middle of the stage as it is drawn now.
	return _slide.global_position + _slide.size * 0.5

func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween

func _tier_rank() -> float:
	## How good the stone inside is, 0 to 1: how much light gets out before it opens.
	return clampf(float(DeepStone.TIERS.find(str(DeepStone.grade(stone).tier))) / float(maxi(1, DeepStone.TIERS.size() - 1)), 0.0, 1.0)

func strike() -> void:
	## One blow. The first two crack it; the third splits it.
	if _phase != "ready":
		return
	_blows += 1
	var heart: Vector2 = _heart()
	DeepUi.shake(_stage, 4.0 + 3.0 * float(_blows), 0.28)
	_art.blows = _blows
	_art.queue_redraw()
	match _blows:
		1:
			DeepAudio.play("pick_strike", {"volume": 0.9})
			_art.dust(heart - _slide.global_position)
			DeepUi.burst(_root, heart + Vector2(0, -60), Color("d8c8a0"), 22, 240.0, 0.7, 4.0)
			_subtitle.text = "A hairline. Strike again."
		2:
			DeepAudio.play("rock_break", {"volume": 0.8})
			DeepAudio.play("loupe_spin", {"volume": 0.5})
			## The light that gets out tells how good the stone is: brighter for a finer one.
			var light: float = 0.25 + 0.55 * _tier_rank()
			_art.light = Color(Color("fff1c4").lerp(_tier_tone, 0.25 * _tier_rank()), light)
			_track(create_tween()).tween_property(_lamp, "modulate:a", 0.15 + 0.35 * _tier_rank(), 0.4)
			DeepUi.burst(_root, heart, Color("fff1c4"), 30, 320.0, 0.8, 5.0)
			_subtitle.text = "Light inside. Once more."
		_:
			_split()

func _split() -> void:
	## The halves fall away, the hollow is lit in the grade's color, the stone rises.
	_phase = "opening"
	var heart: Vector2 = _heart()
	_skip.text = "Click or press Space to skip ahead"
	DeepAudio.play("geode_crack", {"volume": 0.95})
	DeepAudio.play("reveal", {"delay": 0.15, "volume": 0.8})
	_flash.color.a = 0.75
	var t := _track(create_tween())
	t.set_parallel(true)
	t.tween_property(_flash, "color:a", 0.0, 0.7).set_ease(Tween.EASE_OUT)
	if _art != null:
		_art.light = _tier_tone
		t.tween_property(_art, "split", 1.0, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_lamp, "modulate:a", 0.75, 0.5)
	t.tween_property(_rays, "modulate:a", 1.0, 0.8)
	DeepUi.burst(_root, heart, _tier_tone.lightened(0.3), 90, 560.0, 1.3, 9.0)
	DeepUi.burst(_root, heart, Color.WHITE, 40, 340.0, 1.0, 6.0)
	DeepUi.shake(_root, 6.0, 0.35)
	## The stone settles into its place beside where its card will be read out; the rays
	## wait for it there.
	_rays.set("offset", _stage.global_position + _stage.size * 0.5 - _root.size * 0.5)
	var settle := _track(create_tween())
	settle.tween_interval(0.5)
	settle.tween_property(_slide, "position:x", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var rise := _track(create_tween())
	rise.tween_interval(0.35)
	rise.tween_callback(func() -> void:
		_view.modulate.a = 0.0
		_view.scale = Vector2.ONE * 0.5
		_view.pivot_offset = _view.size * 0.5)
	rise.tween_property(_view, "modulate:a", 1.0, 0.35)
	rise.parallel().tween_property(_view, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_method(func(spin: float) -> void: _view.call("set_spin", spin), 9.0, 0.5, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_callback(_grade)
	rise.tween_interval(0.6)
	rise.tween_callback(_read)

func _grade() -> void:
	## The grade, called in its color.
	var grade: Dictionary = DeepStone.grade(stone)
	_title.text = DeepStone.name(stone)
	_title.add_theme_color_override("font_color", _tier_tone.lightened(0.2))
	DeepUi.pulse(_title, 1.25, 0.5)
	_subtitle.text = "%s · %d" % [str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), int(grade.score)]
	_subtitle.add_theme_color_override("font_color", _tier_tone)
	DeepAudio.play(DeepSoundBank.grade_sound(str(grade.tier)), {"volume": 0.9})
	if str(grade.tier) in ["EXQUISITE", "PEERLESS"] or DeepStone.is_opal(stone):
		DeepAudio.play("jackpot", {"delay": 0.2, "volume": 0.7})

func _read() -> void:
	_phase = "reading"
	_card.modulate.a = 0.0
	_track(create_tween()).tween_property(_card, "modulate:a", 1.0, 0.25)
	var beat := _track(create_tween())
	for part in _sheet.call("parts"):
		beat.tween_callback(func() -> void: _sheet.call("reveal", part))
		beat.tween_interval(float(PAUSES.get(str(part).get_slice(":", 0), 0.5)))
	beat.tween_callback(_show_choices)

func _show_choices() -> void:
	_done = true
	_phase = "done"
	_skip.visible = false
	_choices.visible = true
	if new_skill:
		DeepAudio.play("unlock", {"volume": 0.9})
		if _root.is_inside_tree() and not GemView.headless():
			DeepUi.burst(_root, _title.global_position + _title.size * 0.5, DeepUi.ACCENT, 50, 300.0, 1.0, 6.0)
	DeepUi.stagger(_choices.get_children(), 0.0, 0.08, 0.85)

func finish() -> void:
	## Straight to the end: the stone out, every line read, the choices up.
	if _done:
		return
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_dim.modulate.a = 1.0
	if _art != null:
		_art.blows = 3
		_art.split = 1.0
		_art.light = _tier_tone
		_art.wobble = false
	if _swirl != null:
		_swirl.visible = false
	_view.modulate.a = 1.0
	_view.scale = Vector2.ONE
	_view.call("set_spin", 0.5)
	_slide.position.x = 0.0
	_lamp.modulate.a = 0.6
	_rays.modulate.a = 1.0
	_flash.color.a = 0.0
	if _root.is_inside_tree():
		_rays.set("offset", _stage.global_position + _stage.size * 0.5 - _root.size * 0.5)
	if _phase in ["ready", "fusing", "opening"] and not GemView.headless() and is_inside_tree():
		DeepAudio.reveal_stone(stone)
	var grade: Dictionary = DeepStone.grade(stone)
	_title.text = DeepStone.name(stone)
	_title.add_theme_color_override("font_color", _tier_tone.lightened(0.2))
	_subtitle.text = "%s · %d" % [str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), int(grade.score)]
	_subtitle.add_theme_color_override("font_color", _tier_tone)
	_card.modulate.a = 1.0
	_sheet.call("show_all")
	_show_choices()

func close() -> void:
	if not is_instance_valid(self) or is_queued_for_deletion() or _closing:
		return
	_closing = true
	_done = true
	var tween := create_tween()
	tween.set_parallel(true)
	for child in _root.get_children():
		if child is CanvasItem:
			tween.tween_property(child, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(queue_free)
	if _open == self:
		_open = null
	if closed.is_valid():
		closed.call()

func _stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _phase == "ready":
			strike()
		elif not _done:
			finish()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	## Space held down strikes on its own, a blow every third of a second.
	if _phase == "ready" and Input.is_key_pressed(KEY_SPACE):
		_held += delta
		if _held > 0.33:
			_held = 0.0
			strike()
	else:
		_held = 0.0

func _input(event: InputEvent) -> void:
	## Space or Enter strikes (or skips while it plays out); Escape skips to the card, and at
	## the end takes the gentlest way out. Nothing reaches the screen underneath.
	if not is_instance_valid(_root) or is_queued_for_deletion() or _closing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not _done:
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				if _phase == "ready":
					strike()
				else:
					finish()
			elif event.keycode == KEY_ESCAPE:
				finish()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_dismiss()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not _done and _phase != "ready":
		finish()
		get_viewport().set_input_as_handled()

func _dismiss() -> void:
	for action in actions:
		if bool(action.get("dismiss", false)):
			close()
			var run: Callable = action.get("call", Callable())
			if run.is_valid():
				run.call()
			return
	close()

# --- the rock ---------------------------------------------------------------------------------------

class Art extends Control:
	## A Geode, cut low-poly like the stones themselves, in its own mine's rock: pale limestone
	## from the Quarry, wet mossy stone from the Seeps, crystal spurs from the Glass Veins,
	## fungus caps from the Warrens, basalt with lit seams from the Furnace, agate bands from
	## the Hollow, void black with a violet rim from the Rift. A color's Geode shows crystals of
	## its color along its seam; the week's is bound in brass. `blows` cracks it, `split` from
	## 0 to 1 pulls the halves apart with `light` pouring out, and `open` lays it on the shelf
	## opened and empty. `hover` brightens the seam.
	var tone: Color
	var rock: String = "quarry"
	var crystals: Color = Color(0, 0, 0, 0)
	var strapped: bool = false
	var blows: int = 0
	var split: float = 0.0:
		set(value):
			split = value
			queue_redraw()
	var light: Color = Color(1, 0.95, 0.8, 0.0)
	var open: bool = false
	var hover: float = 0.0:
		set(value):
			hover = value
			queue_redraw()
	var wobble: bool = false
	var _seed: int = 1
	var _clock: float = 0.0
	var _puff: Array = []

	const MATERIALS: Dictionary = {
		"quarry": {"base": Color("a89676"), "speck": Color(0, 0, 0, 0.19), "rim": Color("2a2216")},
		"seeps": {"base": Color("3e5c58"), "speck": Color("9fd38a66"), "rim": Color("0d1b1a"), "wet": true},
		"glass": {"base": Color("70709c"), "speck": Color(1, 1, 1, 0.19), "rim": Color("1a1830"), "spurs": Color("c9c4ff")},
		"warrens": {"base": Color("705c42"), "speck": Color("e8dcc040"), "rim": Color("21180e"), "caps": true},
		"furnace": {"base": Color("342c2a"), "speck": Color("ff8a3a50"), "rim": Color("0b0807"), "veins": Color("ff7a2a")},
		"hollow": {"base": Color("8c7ea0"), "speck": Color(1, 1, 1, 0.13), "rim": Color("1d1726"), "bands": true},
		"rift": {"base": Color("1e182c"), "speck": Color(1, 1, 1, 0.67), "rim": Color("000000"), "rift": true},
	}
	const BY_MINE: Dictionary = {"QUARRY": "quarry", "SEEPS": "seeps", "GLASS_VEINS": "glass", "WARRENS": "warrens", "FURNACE": "furnace", "GEODE": "hollow", "RIFT": "rift"}
	const LIGHT_DIR := Vector3(-0.5, -0.62, 0.6)

	func _init(shelf_geode: Dictionary, color: Color) -> void:
		tone = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		rock = str(BY_MINE.get(str(shelf_geode.get("mine", "QUARRY")), "quarry"))
		if str(shelf_geode.get("kind", "")) == "color":
			crystals = DeepUi.color(str(shelf_geode.get("theme", "")))
		strapped = bool(shelf_geode.get("weekly", false))
		_seed = absi(hash(str(shelf_geode.get("id", shelf_geode.get("theme", "geode"))))) % 100000 + 1

	func _process(delta: float) -> void:
		_clock += delta
		if wobble or hover > 0.0 or blows > 0 or split > 0.0:
			queue_redraw()

	func dust(at: Vector2) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed + 99
		for i in range(18):
			_puff.append({"at": at + Vector2(rng.randf_range(-60, 60), rng.randf_range(-90, -20)), "v": Vector2(rng.randf_range(-40, 40), rng.randf_range(-90, -20)), "life": 1.0})

	func _shape() -> Dictionary:
		## The rock's outline, an inner ring and a hub, in the space the control gives it.
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 7 + 3
		var count: int = 13
		var reach: float = minf(size.x / 2.3, size.y / 2.1) * (1.0 if strapped else 0.92)
		var centre := Vector2(size.x * 0.5, size.y * 0.52)
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in range(count):
			var a: float = float(i) / float(count) * TAU + (rng.randf() - 0.5) * 0.25
			var k: float = 0.84 + rng.randf() * 0.16
			outer.append(centre + Vector2(cos(a) * reach * k * 1.1, sin(a) * reach * k * 0.92))
			var b: float = a + PI / float(count)
			var kk: float = 0.5 + rng.randf() * 0.12
			inner.append(centre + Vector2(cos(b) * reach * kk * 1.1 - reach * 0.06, sin(b) * reach * kk * 0.92 - reach * 0.06))
		return {"outer": outer, "inner": inner, "hub": centre - Vector2(reach * 0.1, reach * 0.12), "c": centre, "r": reach, "rng": rng}

	func _crack(g: Dictionary) -> Array:
		## The seam it splits along, top to bottom, and the cracks that branch off it.
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 13 + 5
		var r: float = g.r
		var main := PackedVector2Array()
		var x: float = g.c.x + rng.randf_range(-5, 5)
		var y: float = g.c.y - r * 0.98
		main.append(Vector2(x, y))
		while y < g.c.y + r * 0.95:
			y += r * 0.16
			x += rng.randf_range(-0.16, 0.16) * r
			main.append(Vector2(x, y))
		var branches: Array = []
		for _b in range(6):
			var start: Vector2 = main[rng.randi_range(1, main.size() - 2)]
			var branch := PackedVector2Array([start])
			var bx: float = start.x
			var by: float = start.y
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			for _k in range(3):
				bx += side * r * rng.randf_range(0.12, 0.24)
				by += rng.randf_range(-0.06, 0.14) * r
				branch.append(Vector2(bx, by))
			branches.append(branch)
		return [main, branches]

	func _seam_x(main: PackedVector2Array, y: float) -> float:
		for i in range(main.size() - 1):
			if y >= main[i].y and y <= main[i + 1].y:
				return lerpf(main[i].x, main[i + 1].x, (y - main[i].y) / maxf(0.001, main[i + 1].y - main[i].y))
		return main[0].x if y < main[0].y else main[main.size() - 1].x

	func _draw() -> void:
		var g: Dictionary = _shape()
		var mat: Dictionary = MATERIALS.get(rock, MATERIALS.quarry)
		var crack: Array = _crack(g)
		var main: PackedVector2Array = crack[0]
		var glow: Texture2D = DeepUi.glow_texture()
		var r: float = g.r
		var bob: Vector2 = Vector2(sin(_clock * 2.2) * 2.0, 0.0) if wobble and blows == 0 else Vector2.ZERO
		draw_texture_rect(glow, Rect2(Vector2(g.c.x - r * 1.0, size.y * 0.86), Vector2(r * 2.0, size.y * 0.12)), false, Color(0, 0, 0, 0.6))
		var opening: float = 1.0 if open else split
		if opening > 0.0:
			## The light from the hollow, behind the halves.
			var lit: Color = light if not open else Color(tone, 0.35)
			var halo: float = r * (1.6 + 1.2 * opening)
			draw_texture_rect(glow, Rect2(g.c - Vector2(halo, halo), Vector2(halo, halo) * 2.0), false, Color(lit, 0.85 * lit.a if not open else 0.3))
		var halves: Array = [-1, 1] if opening > 0.0 else [0]
		for side in halves:
			var shift := Vector2(float(side) * r * 0.55 * opening, r * 0.08 * opening * (1.0 if open else 0.6)) + bob
			var tilt: float = float(side) * 0.16 * opening
			draw_set_transform(g.c + shift, tilt, Vector2.ONE)
			_draw_rock(g, mat, side, main, -g.c)
			if opening > 0.0:
				_draw_hollow(g, side, main, -g.c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if opening <= 0.0:
			_draw_marks(g, mat, crack, bob)
		## Grit in the air after a blow.
		for p in _puff:
			p.life = float(p.life) - 0.016
			p.at = Vector2(p.at) + Vector2(p.v) * 0.016
			p.v = Vector2(p.v) + Vector2(0, 220) * 0.016
			if float(p.life) > 0.0:
				draw_circle(p.at, 1.6 + 1.6 * float(p.life), Color(0.85, 0.79, 0.66, float(p.life)))
		_puff = _puff.filter(func(p: Dictionary) -> bool: return float(p.life) > 0.0)

	func _facet_color(base: Color, tri: PackedVector2Array, g: Dictionary, jitter: float) -> Color:
		var mid: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
		var nx: float = (mid.x - g.c.x) / (g.r * 1.1)
		var ny: float = (mid.y - g.c.y) / (g.r * 0.95)
		var nz: float = sqrt(maxf(0.05, 1.0 - nx * nx - ny * ny))
		var shade: float = clampf((nx * LIGHT_DIR.x + ny * LIGHT_DIR.y + nz * LIGHT_DIR.z) / LIGHT_DIR.length() + jitter, 0.0, 1.0)
		var f: float = 0.32 + 0.9 * shade
		return Color(minf(1.0, base.r * f), minf(1.0, base.g * f), minf(1.0, base.b * f))

	func _draw_rock(g: Dictionary, mat: Dictionary, side: int, main: PackedVector2Array, offset: Vector2) -> void:
		## The rock's facets; for a half, only those on its side of the seam.
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 31
		var outer: PackedVector2Array = g.outer
		var inner: PackedVector2Array = g.inner
		var count: int = outer.size()
		var tris: Array = []
		for i in range(count):
			var n: int = (i + 1) % count
			tris.append(PackedVector2Array([g.hub, inner[i], inner[n]]))
			tris.append(PackedVector2Array([inner[i], outer[i], outer[n]]))
			tris.append(PackedVector2Array([inner[i], outer[n], inner[n]]))
		for tri in tris:
			var jitter: float = rng.randf_range(-0.08, 0.08)
			if side != 0:
				var mid: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
				if (mid.x < _seam_x(main, mid.y)) != (side < 0):
					continue
			var shown := PackedVector2Array([tri[0] + offset, tri[1] + offset, tri[2] + offset])
			draw_colored_polygon(shown, _facet_color(mat.base, tri, g, jitter))
		var specks := RandomNumberGenerator.new()
		specks.seed = _seed * 17
		for _i in range(40):
			var p: Vector2 = g.c + Vector2(specks.randf_range(-1.0, 1.0) * g.r * 0.95, specks.randf_range(-1.0, 1.0) * g.r * 0.8)
			if not Geometry2D.is_point_in_polygon(p, outer):
				continue
			if side != 0 and (p.x < _seam_x(main, p.y)) != (side < 0):
				continue
			draw_circle(p + offset, specks.randf_range(0.8, 2.2), mat.speck)
		if mat.get("wet", false):
			for i in range(6):
				var x: float = g.c.x - g.r * 0.6 + specks.randf() * g.r * 0.8
				var y: float = g.c.y - g.r * 0.6 + specks.randf() * g.r * 0.5
				if side == 0 or (x < _seam_x(main, y)) == (side < 0):
					draw_polyline(PackedVector2Array([Vector2(x, y) + offset, Vector2(x + 6, y + 11) + offset, Vector2(x + 3, y + 24) + offset]), Color(0.9, 1.0, 0.98, 0.35), 1.6, true)
		if mat.has("veins"):
			for k in range(3):
				var pts := PackedVector2Array()
				var x: float = g.c.x - g.r + specks.randf() * g.r * 0.4
				var y: float = g.c.y - g.r * 0.5 + specks.randf() * g.r
				for s in range(7):
					if Geometry2D.is_point_in_polygon(Vector2(x, y), outer) and (side == 0 or (x < _seam_x(main, y)) == (side < 0)):
						pts.append(Vector2(x, y) + offset)
					x += g.r * 0.28
					y += specks.randf_range(-0.17, 0.17) * g.r
				if pts.size() > 1:
					draw_polyline(pts, Color(mat.veins, 0.35), 6.0, true)
					draw_polyline(pts, mat.veins, 2.0, true)
		if mat.get("bands", false):
			for k in range(4):
				var band := PackedVector2Array()
				for s in range(33):
					var a: float = float(s) / 32.0 * TAU
					var p: Vector2 = g.c + Vector2(g.r * 0.25, g.r * 0.2) + Vector2(cos(a) * g.r * (0.32 + float(k) * 0.1), sin(a) * g.r * (0.24 + float(k) * 0.08)).rotated(-0.4)
					if Geometry2D.is_point_in_polygon(p, outer) and (side == 0 or (p.x < _seam_x(main, p.y)) == (side < 0)):
						band.append(p + offset)
					elif band.size() > 1:
						draw_polyline(band, [Color("e8d9ff55"), Color("7a5fb055"), Color("ffffff40"), Color("b49ad855")][k], 3.0, true)
						band = PackedVector2Array()
				if band.size() > 1:
					draw_polyline(band, [Color("e8d9ff55"), Color("7a5fb055"), Color("ffffff40"), Color("b49ad855")][k], 3.0, true)
		if strapped:
			var straps: Array = [[g.c + Vector2(-g.r * 0.35, -g.r), g.c + Vector2(-g.r * 0.15, g.r)], [g.c + Vector2(-g.r * 1.2, g.r * 0.05), g.c + Vector2(g.r * 1.2, -g.r * 0.1)]]
			for strap in straps:
				var a: Vector2 = strap[0]
				var b: Vector2 = strap[1]
				var clipped: PackedVector2Array = _inside(PackedVector2Array([a, b]), outer, side, main, 24)
				if clipped.size() > 1:
					for i in range(clipped.size() - 1):
						draw_line(clipped[i] + offset, clipped[i + 1] + offset, Color("b8862f"), g.r * 0.13)
						draw_line(clipped[i] + offset, clipped[i + 1] + offset, Color("f3d27a"), g.r * 0.05)
			var rivet: Vector2 = g.c + Vector2(-g.r * 0.26, 0)
			if side == 0 or (rivet.x < _seam_x(main, rivet.y)) == (side < 0):
				draw_circle(rivet + offset, g.r * 0.1, Color("f3d27a"))
				draw_arc(rivet + offset, g.r * 0.1, 0, TAU, 20, Color("6d4c16"), 1.5, true)
		var rim := PackedVector2Array()
		for p in outer:
			if side == 0 or (p.x < _seam_x(main, p.y)) == (side < 0):
				rim.append(p + offset)
		if side == 0:
			rim.append(outer[0] + offset)
			draw_polyline(rim, mat.rim, 2.0, true)
			if mat.get("rift", false):
				draw_polyline(rim, Color(0.65, 0.48, 1.0, 0.45), 5.0, true)
		if mat.has("spurs") and side == 0:
			_spurs(g, mat.spurs, [1, 4, 7, 9, 11], offset)
		if crystals.a > 0.0 and side == 0:
			var along: Array = []
			for i in range(1, mini(6, main.size())):
				along.append(main[i])
			_shards(g, crystals, along, offset, -PI * 0.5)
		if mat.get("caps", false) and side == 0:
			for i in range(4):
				var p: Vector2 = outer[(i * 3 + 1) % outer.size()] + offset
				var cap := PackedVector2Array()
				for s in range(9):
					var a: float = PI + PI * float(s) / 8.0
					cap.append(p + Vector2(cos(a) * 9.0, sin(a) * 5.0 - 3.0))
				draw_colored_polygon(cap, Color("e9dcc0"))
				draw_rect(Rect2(p + Vector2(-1.5, -3), Vector2(3, 7)), Color("b9a98a"))

	func _inside(segment: PackedVector2Array, outer: PackedVector2Array, side: int, main: PackedVector2Array, steps: int) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(steps + 1):
			var p: Vector2 = segment[0].lerp(segment[1], float(i) / float(steps))
			if Geometry2D.is_point_in_polygon(p, outer) and (side == 0 or (p.x < _seam_x(main, p.y)) == (side < 0)):
				out.append(p)
		return out

	func _spurs(g: Dictionary, color: Color, at: Array, offset: Vector2) -> void:
		var points: Array = []
		for i in at:
			points.append(g.outer[int(i) % g.outer.size()])
		_shards(g, color, points, offset, 0.0)

	func _shards(g: Dictionary, color: Color, at: Array, offset: Vector2, lean: float) -> void:
		## Crystal points: from the rim outward, or along the seam upward.
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 3
		for p in at:
			var base: Vector2 = Vector2(p)
			var angle: float = (base - g.c).angle() if lean == 0.0 else lean + rng.randf_range(-0.6, 0.6)
			angle += rng.randf_range(-0.3, 0.3)
			var length: float = g.r * rng.randf_range(0.18, 0.34)
			var width: float = length * 0.32
			var tip: Vector2 = base + Vector2.from_angle(angle) * length
			var n: Vector2 = Vector2.from_angle(angle + PI * 0.5) * width
			draw_colored_polygon(PackedVector2Array([base + n + offset, tip + offset, base - n + offset]), Color(color, 0.92))
			draw_colored_polygon(PackedVector2Array([base + offset, tip + offset, base + n + offset]), Color(1, 1, 1, 0.4))
			if hover > 0.0:
				draw_texture_rect(DeepUi.glow_texture(), Rect2(tip + offset - Vector2.ONE * 10.0, Vector2.ONE * 20.0), false, Color(color, 0.6 * hover))

	func _draw_marks(g: Dictionary, mat: Dictionary, crack: Array, bob: Vector2) -> void:
		## The seam, and once struck the cracks: a hairline, then the crack run through with
		## light pushing out of it.
		var main: PackedVector2Array = crack[0]
		var shown := PackedVector2Array()
		var upto: int = main.size() if blows >= 2 else (4 if blows == 1 else main.size())
		for i in range(upto):
			shown.append(main[i] + bob)
		if blows == 0:
			## Unstruck: a faint seam, brighter while the pointer is on its button.
			draw_polyline(shown, Color(tone, 0.25 + 0.45 * hover), 1.5 + hover, true)
			return
		var lit: Color = light if light.a > 0.0 else Color("f3e2b0")
		var width: float = 1.4 if blows == 1 else 2.6
		if blows >= 2:
			draw_polyline(shown, Color(lit, 0.35), width * 4.0, true)
		draw_polyline(shown, Color(0.04, 0.03, 0.03), width + 2.4, true)
		draw_polyline(shown, lit if blows >= 2 else Color("e8d8a8"), width, true)
		var branches: Array = crack[1]
		for b in range(2 if blows == 1 else branches.size()):
			var branch: PackedVector2Array = branches[b]
			var moved := PackedVector2Array()
			for p in branch:
				moved.append(p + bob)
			draw_polyline(moved, Color(0.04, 0.03, 0.03), (1.0 if blows == 1 else 1.8) + 2.0, true)
			draw_polyline(moved, lit if blows >= 2 else Color("d9c89a"), 1.0 if blows == 1 else 1.8, true)
		if blows >= 2:
			var pulse: float = 0.75 + 0.25 * sin(_clock * 6.0)
			draw_texture_rect(DeepUi.glow_texture(), Rect2(g.c - Vector2(g.r, g.r) * 1.2, Vector2(g.r, g.r) * 2.4), false, Color(lit, 0.4 * lit.a * pulse))

	func _draw_hollow(g: Dictionary, side: int, main: PackedVector2Array, offset: Vector2) -> void:
		## A half's face: a rind round a hollow lined with crystal, lit from inside.
		var hollow := PackedVector2Array()
		for p in g.outer:
			var q: Vector2 = g.c + (p - g.c) * Vector2(0.74, 0.72)
			if (q.x < _seam_x(main, q.y)) == (side < 0):
				hollow.append(q)
		var seam_part := PackedVector2Array()
		for p in main:
			if absf(p.y - g.c.y) < g.r * 0.68:
				seam_part.append(p)
		if side < 0:
			seam_part.reverse()
		for p in seam_part:
			hollow.append(p)
		if hollow.size() < 3:
			return
		var ordered: PackedVector2Array = Geometry2D.convex_hull(hollow)
		var shown := PackedVector2Array()
		for p in ordered:
			shown.append(p + offset)
		draw_colored_polygon(shown, Color("120c14"))
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 11 + (side + 2)
		var lining: Color = light if not open and light.a > 0.0 else tone
		for _i in range(60):
			var p: Vector2 = ordered[rng.randi_range(0, ordered.size() - 1)].lerp(g.c, rng.randf() * 0.5)
			if not Geometry2D.is_point_in_polygon(p, ordered):
				continue
			var c: Color = Color(lining if rng.randf() < 0.5 else Color.WHITE, 0.25 + rng.randf() * 0.6)
			draw_colored_polygon(PackedVector2Array([p + offset + Vector2(0, -5), p + offset + Vector2(3, 2), p + offset + Vector2(-3, 2)]), c)

# --- a contract's five stones -------------------------------------------------------------------------

class Swirl extends Control:
	## Five stones circling in to the middle of the bench until they meet in a flash.
	const LIFE: float = 2.2
	var stones: Array = []
	var _clock: float = -1.0
	var _thumbs: Array = []

	func _init(inputs: Array) -> void:
		stones = inputs
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		for stone in stones:
			var thumb := Thumbs.GemThumb.new(stone, 72.0)
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(thumb)
			_thumbs.append(thumb)
		_place()

	func begin() -> void:
		_clock = 0.0

	func _process(delta: float) -> void:
		if _clock >= 0.0:
			_clock += delta
			_place()
			queue_redraw()

	func _place() -> void:
		var t: float = clampf(_clock / LIFE, 0.0, 1.0) if _clock >= 0.0 else 0.0
		var reach: float = minf(size.x, size.y) * 0.38 * (1.0 - t * t)
		for i in range(_thumbs.size()):
			var angle: float = TAU * float(i) / float(maxi(1, _thumbs.size())) + t * TAU * 1.5
			var thumb: Control = _thumbs[i]
			thumb.position = size * 0.5 + Vector2.from_angle(angle) * reach - Vector2(36, 36)
			thumb.modulate.a = 1.0 - smoothstep(0.85, 1.0, t)

	func _draw() -> void:
		if _clock < 0.0:
			return
		var t: float = clampf(_clock / LIFE, 0.0, 1.0)
		var glow: float = minf(size.x, size.y) * (0.2 + 0.6 * t)
		draw_texture_rect(DeepUi.glow_texture(), Rect2(size * 0.5 - Vector2.ONE * glow, Vector2.ONE * glow * 2.0), false, Color(DeepUi.ACCENT_HI, 0.25 + 0.5 * t))
