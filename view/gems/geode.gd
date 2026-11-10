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
## middle of the bench and come out as one. A twin fused down the mine (`twin`, November 5,
## 2026) is the same two-stone swirl, and before the sheet its weight rolls up from the heavier
## of the two to what the fire made.
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
## The Geode itself, in 3D: the shelf draws it too.
const Art = preload("res://view/gems/geode_view.gd")

const RARITIES: Array = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY", "MYTHIC"]
## How long each line of the sheet holds before the next is read.
const PAUSES: Dictionary = {"name": 0.55, "carat": 0.45, "cut": 0.4, "clarity": 0.45, "inclusions": 0.45,
	"inclusion": 0.6, "grade": 0.8, "worth": 0.5, "compare": 0.5}
const STAGE := Vector2(560, 420)
## A twin's two stones circle in for this long, and its weight rolls up over this long.
const TWIN_LIFE: float = 1.8
const ROLL: float = 0.6

static var _open: CanvasLayer = null

var geode: Dictionary = {}
var given: Array = []
var stone: Dictionary = {}
var owned: Dictionary = {}
## Each a choice: {label, glyph, tone, caption, call, primary, dismiss, price}.
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
## The phone's: the column it all stands in, the sheet's scroll and the foot under the card.
var _column: VBoxContainer
var _sheet_scroll: ScrollContainer
var _foot: VBoxContainer
var _skip: Label
var _choices: Control
var _flash: ColorRect
## A twin's weight, rolling up under the stone from the heavier that went in.
var _carat_label: Label = null
var _carat_from: int = 1
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

static func twin(inputs: Array, made: Dictionary, opts: Dictionary = {}, when_closed: Callable = Callable()) -> CanvasLayer:
	## A twin fused into the stone it matches: `inputs` the held stone then the newcomer, `made`
	## what came out. opts: owned (the held stone as it was, read beside the result), from_carat
	## (where the weight starts rolling from), paid, actions.
	return _show("twin", {}, inputs, made, opts, when_closed)

static func current() -> CanvasLayer:
	return _open if is_open() else null

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
	DeepUi.use_theme(_root)
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
	## The phone's column stands inside the safe edges (Appraisal.fit_phone holds it there).
	if DeepUi.phone:
		centre.offset_top = DeepUi.safe_top + Appraisal.PHONE_EDGE
		centre.offset_bottom = -(DeepUi.safe_bottom + Appraisal.PHONE_EDGE)
	var column := DeepUi.vbox(centre, int(DeepUi.pt(3)) if DeepUi.phone else 10)
	_column = column
	var titles: Dictionary = {"geode": geode_name(geode), "contract": "The contract", "twin": "Two of a kind"}
	var subtitles: Dictionary = {"geode": "Strike it. Three blows open it.", "contract": "Five stones go in; one comes out.",
		"twin": "Two stones go into the fire. The heavier comes out, and maybe a little more."}
	_title = DeepUi.title(column, str(opts.get("title", titles.get(mode, "The contract"))), 32 if DeepUi.phone else 40, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("outline_size", 10)
	_subtitle = DeepUi.label(column, str(opts.get("subtitle", subtitles.get(mode, ""))), 12 if DeepUi.phone else 16, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var row := DeepUi.hbox(column, int(DeepUi.pt(10)) if DeepUi.phone else 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage = Control.new()
	## The phone's stage: what the screen leaves beside the card (board run-moments).
	_stage.custom_minimum_size = Vector2(DeepUi.pt(250), DeepUi.pt(200)) if DeepUi.phone else STAGE
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
		_art.bench = true
		_art.drifting = false
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slide.add_child(_art)
	else:
		_swirl = Swirl.new(given, TWIN_LIFE if mode == "twin" else Swirl.LIFE)
		_swirl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_swirl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slide.add_child(_swirl)
	if mode == "twin":
		## The weight, under the stone once it is out: it rolls up from the heavier of the two.
		_carat_from = int(opts.get("from_carat", stone.get("carat", 1)))
		_carat_label = Label.new()
		_carat_label.text = "%d ct" % _carat_from
		_carat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_carat_label.add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.set_text_size(_carat_label, 34)
		_carat_label.add_theme_color_override("font_color", DeepUi.PAPER)
		_carat_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_carat_label.add_theme_constant_override("outline_size", 8)
		_carat_label.anchor_left = 0.5
		_carat_label.anchor_right = 0.5
		_carat_label.anchor_top = 0.5
		_carat_label.anchor_bottom = 0.5
		_carat_label.offset_left = -120
		_carat_label.offset_right = 120
		_carat_label.offset_top = 118
		_carat_label.offset_bottom = 164
		_carat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_carat_label.visible = false
		_slide.add_child(_carat_label)
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
	## GemView._ready sets PASS: the stone hidden in the rock must not answer a hover (its
	## tooltip would read the stone out before the rock is open) or cover the card after.
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## The card the stone is read out on, beside it once it is out.
	_card = PanelContainer.new()
	_card_style = DeepUi.raised(Color(0.045, 0.055, 0.09, 0.97), Color(_tier_tone, 0.7), 16, int(DeepUi.pt(8)) if DeepUi.phone else 18, 0.6)
	_card_style.set_border_width_all(2)
	_card.add_theme_stylebox_override("panel", _card_style)
	## Unseen until the stone is read, and the rock is drawn over where it will stand (see
	## `_centring`), so until then it lets every click through to the rock.
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	row.add_child(_card)
	var card_box := DeepUi.vbox(_card, int(DeepUi.pt(3)) if DeepUi.phone else 8)
	if new_skill:
		var fanfare := DeepUi.hbox(card_box, 8)
		DeepUi.pill(fanfare, "star", "New skill", StoneCard.PIP_NEW, 12 if DeepUi.phone else 14)
		DeepUi.label(fanfare, "Your first %s" % DeepUi.skill_name(stone), 12 if DeepUi.phone else 14, DeepUi.GOOD)
	if not wanted.is_empty():
		DeepUi.stat(card_box, "flag", wanted, DeepUi.GOOD, 13)
	var sheet_opts: Dictionary = {"skill_text": true, "owned_picture": false}
	if mode == "twin":
		## Read beside the stone as it was before the fire, not beside a vault's stone.
		sheet_opts = {"skill_text": false, "owned_picture": false, "found_heading": "Out of the fire", "owned_heading": "Before", "owned_note": "the one you held"}
	_sheet = Appraisal.Sheet.new(stone, owned, Appraisal.phone_sheet(sheet_opts))
	_sheet_scroll = Appraisal.phone_scroll(card_box, _sheet)
	if mode == "twin" and int(opts.get("paid", 0)) > 0:
		DeepUi.stat(card_box, "ore", "%d pyrite paid" % int(opts.get("paid", 0)), DeepUi.ORE, 12)
	var foot := DeepUi.vbox(column, 6)
	foot.custom_minimum_size.y = DeepUi.pt(40) if DeepUi.phone else 80.0
	_foot = foot
	_skip = DeepUi.label(foot, ("Tap the Geode to strike" if mode == "geode" else "Tap to skip ahead") if DeepUi.phone else ("Click the Geode or press Space to strike · Esc skips" if mode == "geode" else "Click or press Space to skip ahead"), 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_choices = Appraisal.choices(foot, actions, close)
	_choices.visible = false
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_fit_soon()

func _fit_soon() -> void:
	## The phone's fit (Appraisal.fit_phone), two frames on, once every wrapped line knows its width.
	if not DeepUi.phone or not is_inside_tree():
		return
	for i in range(2):
		await get_tree().process_frame
	if is_instance_valid(self) and not _closing and _column != null:
		Appraisal.fit_phone(_column, _sheet_scroll, _stage, DeepUi.pt(200), _foot, _choices)

# --- what the shelf and this page say about a Geode ---------------------------------------------------

static func geode_name(shelf_geode: Dictionary) -> String:
	return DeepEconomy.geode_name(shelf_geode)

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
	if mode in ["contract", "twin"]:
		_phase = "fusing"
		_swirl.begin()
		DeepAudio.play("altar_hum", {"volume": 0.7})
		var beat := _track(create_tween())
		beat.tween_interval(_swirl.life)
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
	_skip.text = "Tap to skip ahead" if DeepUi.phone else "Click or press Space to skip ahead"
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
	if mode == "twin":
		## Its weight rolls up under it before a line of the sheet is read.
		rise.tween_callback(_roll_carat)
		rise.tween_interval(ROLL + 0.5)
	else:
		rise.tween_interval(0.6)
	rise.tween_callback(_read)

func _roll_carat() -> void:
	## The weight counts up from the heavier stone that went in to what came out, and says by
	## how much; a stone no heavier for it says so plainly.
	if _carat_label == null:
		return
	var to: int = int(stone.get("carat", 1))
	_carat_label.text = "%d ct" % _carat_from
	_carat_label.modulate.a = 0.0
	_carat_label.visible = true
	_carat_label.pivot_offset = _carat_label.size * 0.5
	var roll := _track(create_tween())
	roll.tween_property(_carat_label, "modulate:a", 1.0, 0.15)
	roll.tween_method(func(value: float) -> void: _carat_label.text = "%d ct" % int(round(value)), float(_carat_from), float(to), ROLL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	roll.tween_callback(func() -> void:
		_carat_label.text = "%d ct" % to
		var gain: int = to - _carat_from
		if gain > 0:
			_carat_label.add_theme_color_override("font_color", DeepUi.GOOD)
			DeepUi.pulse(_carat_label, 1.3, 0.4)
			DeepAudio.play("keep", {"volume": 0.8})
			if _root.is_inside_tree():
				var at: Vector2 = _carat_label.global_position + _carat_label.size * 0.5 - _root.global_position
				DeepUi.burst(_root, at, DeepUi.GOOD, 26, 220.0, 0.7, 5.0)
				DeepUi.float_text(_root, at - Vector2(0, 58), "+%d ct" % gain, DeepUi.GOOD, 24, 50.0, 1.4)
		elif _root.is_inside_tree():
			DeepUi.float_text(_root, _carat_label.global_position + _carat_label.size * 0.5 - _root.global_position - Vector2(0, 58), "no heavier", DeepUi.MUTED, 18, 40.0, 1.2))

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
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.modulate.a = 0.0
	_track(create_tween()).tween_property(_card, "modulate:a", 1.0, 0.25)
	var beat := _track(create_tween())
	for part in _sheet.call("parts"):
		beat.tween_callback(func() -> void:
			_sheet.call("reveal", part)
			## On the phone a line read below the scroll's window is scrolled to.
			if _sheet_scroll != null and is_instance_valid(_sheet_scroll) and _sheet.call("anchor_of", part) != null:
				_sheet_scroll.ensure_control_visible(_sheet.call("anchor_of", part)))
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
	_fit_soon()

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
	if _carat_label != null:
		_carat_label.visible = true
		_carat_label.modulate.a = 1.0
		_carat_label.text = "%d ct" % int(stone.get("carat", 1))
		if int(stone.get("carat", 1)) > _carat_from:
			_carat_label.add_theme_color_override("font_color", DeepUi.GOOD)
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
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _phase == "ready" \
			and _slide.get_global_rect().has_point(event.position):
		## The rock is drawn right of the stage it stands on (see `_centring`), so a blow lands
		## wherever the rock is seen, not only over the part still above its stage.
		strike()
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

# --- a contract's five stones -------------------------------------------------------------------------

class Swirl extends Control:
	## Five stones circling in to the middle of the bench until they meet in a flash.
	const LIFE: float = 2.2
	var stones: Array = []
	## How long the circling takes: a twin's two stones meet sooner than a contract's five.
	var life: float = LIFE
	var _clock: float = -1.0
	var _thumbs: Array = []

	func _init(inputs: Array, seconds: float = LIFE) -> void:
		stones = inputs
		life = maxf(0.1, seconds)
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
		var t: float = clampf(_clock / life, 0.0, 1.0) if _clock >= 0.0 else 0.0
		var reach: float = minf(size.x, size.y) * 0.38 * (1.0 - t * t)
		for i in range(_thumbs.size()):
			var angle: float = TAU * float(i) / float(maxi(1, _thumbs.size())) + t * TAU * 1.5
			var thumb: Control = _thumbs[i]
			thumb.position = size * 0.5 + Vector2.from_angle(angle) * reach - Vector2(36, 36)
			thumb.modulate.a = 1.0 - smoothstep(0.85, 1.0, t)

	func _draw() -> void:
		if _clock < 0.0:
			return
		var t: float = clampf(_clock / life, 0.0, 1.0)
		var glow: float = minf(size.x, size.y) * (0.2 + 0.6 * t)
		draw_texture_rect(DeepUi.glow_texture(), Rect2(size * 0.5 - Vector2.ONE * glow, Vector2.ONE * glow * 2.0), false, Color(DeepUi.ACCENT_HI, 0.25 + 0.5 * t))
