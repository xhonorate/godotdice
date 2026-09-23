extends CanvasLayer
## The appraisal: a raw stone under the loupe, worked out of its rock and read out.
##
## The stone turns on the lamp with its matrix still on it. The rock comes off a chunk at a
## time, smallest first, each one a tap of the hammer and a spray of grit; then the stone
## spins up, the light inside it finds the cracks in what is left, and the last and largest
## chunk splits away in a flash and a flare. Only then is anything said, one line at a time:
## its name, its carat, its cut and its clarity; whatever is frozen inside it, one inclusion
## after another; and last its grade and its worth. Then the choice, which depends on where
## the stone was read: at home, which of two to keep, this one or the one of its skill already
## in the vault; down the mine, the bag, a socket or the merchant's scales.
##
## A click or Space skips to the end at any point; Escape at the end takes the gentlest way
## out (it waits on the tray, it goes in the bag). The `Sheet` read out here is also how a
## known stone is weighed against the one already kept, on the Appraise tab, so a comparison
## looks the same wherever it is made.

const GemView = preload("res://view/gems/gem_view.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const GemRock = preload("res://view/gems/gem_rock.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const Inspector = preload("res://view/inspect/inspector.gd")

const STAGE := Vector2(440, 440)
## How long each line of the sheet holds before the next is read.
const PAUSES: Dictionary = {"name": 0.95, "carat": 0.8, "cut": 0.65, "clarity": 0.85, "inclusions": 0.85,
	"inclusion": 1.05, "grade": 1.35, "worth": 0.85, "compare": 0.8}

static var _open: CanvasLayer = null

## The stone as it is once known, and the one it is weighed against, if any.
var stone: Dictionary = {}
var owned: Dictionary = {}
## Each a choice: {label, glyph, tone, caption, call, primary, dismiss}.
var actions: Array = []
var _root: Control
var _dim: ColorRect
var _rays: Control
var _halo: Control
var _lamp: TextureRect
var _stage: Control
var _view: Control
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _title: Label
var _subtitle: Label
var _sheet: Sheet
var _skip: Label
var _choices: Control
var _gleam: Gleam
var _flash: ColorRect
var _tweens: Array = []
var _hue: Color = Color.WHITE
## Where the sequence has got to: the rock is off, the grade has been read, it is all over.
var _opened: bool = false
var _graded: bool = false
var _done: bool = false
var _closing: bool = false

static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)

static func open(raw: Dictionary, opts: Dictionary = {}) -> CanvasLayer:
	## Puts a raw stone under the loupe and plays the whole appraisal. `opts` may carry
	## `owned` (the stone of its skill already kept, to weigh it against), `actions` (the
	## choices at the end) and `title`. Nothing happens without a display.
	if DisplayServer.get_name() == "headless":
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if is_open():
		_open.queue_free()
	Inspector.close()
	var made: CanvasLayer = load("res://view/gems/appraisal.gd").new()
	tree.root.add_child(made)
	made.call("build", raw, opts)
	made.call("play")
	_open = made
	return made

# --- building ----------------------------------------------------------------------------------

func build(raw: Dictionary, opts: Dictionary = {}) -> void:
	## Everything the appraisal will show, laid out from the start and hidden, so nothing
	## moves as it is revealed. `finish()` shows it all at once; `play()` reads it out.
	layer = 61
	stone = raw.duplicate(true)
	stone.appraised = true
	stone.inclusions_revealed = true
	var sealed: Dictionary = raw.duplicate(true)
	sealed.appraised = false
	owned = opts.get("owned", {})
	actions = opts.get("actions", [])
	_hue = GemMesh.tint(stone)
	_root = Control.new()
	_root.theme = DeepUi.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.01, 0.82)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	_rays = Inspector.Rays.new(_hue)
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.modulate.a = 0.0
	_root.add_child(_rays)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	var column := DeepUi.vbox(centre, 12)
	_title = DeepUi.title(column, str(opts.get("title", "Under the loupe")), 40, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("outline_size", 10)
	_subtitle = DeepUi.label(column, "A %s, still in its rock" % DeepStone.raw_name(raw).to_lower(), 16, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_panel = PanelContainer.new()
	_panel_style = DeepUi.raised(Color(0.045, 0.055, 0.08, 0.97), Color(_hue, 0.6), 18, 20, 0.7)
	_panel_style.set_border_width_all(2)
	_panel_style.shadow_color = Color(_hue, 0.2)
	_panel_style.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(_panel)
	var row := DeepUi.hbox(_panel, 28)
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_stage)
	_halo = Inspector.Halo.new(_hue)
	_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_halo)
	## The light inside the stone, turned up as the rock comes off.
	_lamp = DeepUi.glow(_stage, _hue, 0.0, 1.1)
	_view = GemView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_slot(250.0)
	_view.set_drift(true)
	_view.set_spin(0.5)
	_view.configure(sealed)
	_stage.add_child(_view)
	_sheet = Sheet.new(stone, owned, {"skill_text": true})
	_sheet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_sheet)
	var foot := DeepUi.vbox(column, 6)
	foot.custom_minimum_size.y = 76
	_skip = DeepUi.label(foot, "Click or press Space to skip ahead", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_choices = choices(foot, actions, close)
	_choices.visible = false
	_gleam = Gleam.new()
	_gleam.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_gleam)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

static func choices(parent: Node, list: Array, before: Callable = Callable()) -> HBoxContainer:
	## The choices at the end of an appraisal, or under a stone waiting on the tray: a button
	## each, with a line under it saying what it costs. `before` runs first (closing the
	## sheet the buttons sit on).
	var row := DeepUi.hbox(parent, 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for action in list:
		var box := DeepUi.vbox(row, 4)
		var primary: bool = bool(action.get("primary", true))
		var run: Callable = action.get("call", Callable())
		var pressed := func() -> void:
			## One choice, once: a second click on the way out does nothing.
			if bool(row.get_meta("chosen", false)):
				return
			row.set_meta("chosen", true)
			if before.is_valid():
				before.call()
			if run.is_valid():
				run.call()
		var button: Button
		if primary:
			button = DeepUi.primary(box, str(action.get("glyph", "check")), str(action.get("label", "")), pressed, 17, action.get("tone", DeepUi.ACCENT))
			button.custom_minimum_size = Vector2(230, 48)
		else:
			button = DeepUi.icon_button(box, str(action.get("glyph", "check")), str(action.get("label", "")), pressed, 15, DeepUi.MUTED)
			button.custom_minimum_size = Vector2(170, 48)
		if action.has("sound"):
			DeepUi.voice(button, str(action.sound))
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not str(action.get("caption", "")).is_empty():
			DeepUi.label(box, str(action.caption), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	return row

# --- the reading ---------------------------------------------------------------------------------

func play() -> void:
	DeepAudio.play("ui_open", {"volume": 0.6})
	_dim.modulate.a = 0.0
	_track(create_tween()).tween_property(_dim, "modulate:a", 1.0, 0.2)
	DeepUi.pop_in(_panel, 0.0, 0.9, 0.36)
	var count: int = maxi(1, _view.call("chunks_left") if not GemView.headless() else GemRock.chunk_count(stone))
	var beat := _track(create_tween())
	beat.tween_interval(0.9)
	## The rock comes off a chunk at a time and the whole crust must be off in about the
	## same three seconds however many chunks it is in, so the hammer falls faster on a
	## stone that is buried deeper.
	var swing: float = clampf(3.2 / float(maxi(1, count - 1)), 0.42, 1.05)
	for index in range(count - 1):
		beat.tween_callback(_chip.bind(index, count))
		beat.tween_interval(swing if index < count - 2 else swing * 0.8)
	beat.tween_callback(_build_up)
	beat.tween_interval(1.4)
	beat.tween_callback(_break_open)
	beat.tween_interval(1.15)
	for part in _sheet.parts():
		beat.tween_callback(_read.bind(part))
		beat.tween_interval(float(PAUSES.get(str(part).get_slice(":", 0), 0.8)))
	beat.tween_callback(_show_choices)

func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween

func _chip(index: int, count: int) -> void:
	## One chunk off: the hammer, grit, a jolt, and a little more light getting out.
	var at: Vector2 = _view.global_position + _view.call("knock_chunk")
	DeepAudio.play("chisel", {"volume": 0.9})
	_dust(at, GemRock.TONE.lightened(0.25), 34, 360.0)
	DeepUi.burst(_root, at, _hue, 10, 200.0, 0.5, 4.0)
	DeepUi.shake(_stage, 5.0, 0.22)
	var share: float = float(index + 1) / float(count)
	_view.call("glow_cracks", 0.12 + 0.2 * share)
	_view.call("set_spin", 0.5 + 1.6 * share)
	_track(create_tween()).tween_property(_lamp, "modulate:a", 0.12 + 0.18 * share, 0.3)

func _build_up() -> void:
	## The last chunk is the big one. The stone spins up and the light inside it pushes
	## through every crack in the rock that is left.
	DeepAudio.play("loupe_spin")
	var tween := _track(create_tween())
	tween.tween_method(func(t: float) -> void:
		_view.call("set_spin", lerpf(2.1, 12.0, t))
		_view.call("glow_cracks", lerpf(0.35, 1.6, t))
		_lamp.modulate.a = lerpf(0.3, 0.8, t)
		_lamp.scale = Vector2.ONE * lerpf(1.0, 1.25, t), 0.0, 1.0, 1.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	DeepUi.shake(_stage, 3.0, 1.3)

func _break_open() -> void:
	## The bed splits away and the stone is seen whole for the first time.
	_opened = true
	var at: Vector2 = _view.global_position + _view.call("knock_chunk")
	_view.call("configure", stone)
	var heart: Vector2 = _view.global_position + _view.call("centre_point")
	DeepAudio.play("rock_break", {"volume": 0.9})
	DeepAudio.play("gleam", {"delay": 0.04})
	DeepAudio.play("reveal", {"delay": 0.1, "volume": 0.8})
	_dust(at, GemRock.TONE.lightened(0.25), 70, 520.0)
	DeepUi.burst(_root, heart, _hue.lightened(0.3), 90, 540.0, 1.3, 9.0)
	DeepUi.burst(_root, heart, Color.WHITE, 40, 320.0, 1.0, 6.0)
	DeepUi.shake(_panel, 8.0, 0.35)
	_gleam.fire(heart, _hue.lightened(0.45), 150.0)
	_flash.color.a = 0.85
	var tween := _track(create_tween())
	tween.set_parallel(true)
	tween.tween_property(_flash, "color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lamp, "modulate:a", 0.35, 1.2)
	tween.tween_property(_lamp, "scale", Vector2.ONE, 1.2)
	tween.tween_property(_rays, "modulate:a", 1.0, 0.8)
	tween.tween_method(func(spin: float) -> void: _view.call("set_spin", spin), 12.0, 0.45, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rays.set("offset", _stage_centre() - _root.size * 0.5)
	_title.text = "Appraised"
	_title.add_theme_color_override("font_color", _hue.lightened(0.4))
	DeepUi.pulse(_title, 1.25, 0.5)
	_subtitle.text = "Out of the rock at last. Here is what the loupe says."

func _read(part: String) -> void:
	_sheet.reveal(part)
	match part:
		"name":
			DeepUi.burst(_root, _sheet.name_point(), _hue.lightened(0.3), 30, 260.0, 0.8, 6.0)
		"grade":
			_graded = true
			get_tree().create_timer(0.9).timeout.connect(func() -> void:
				if is_instance_valid(self) and not _done:
					_tint(DeepUi.tier_color(str(DeepStone.grade(stone).tier)), true))
		"compare":
			_subtitle.text = _question()

func _question() -> String:
	## What the choice at home really is, when one of its skill is already kept.
	return "Only one %s can be kept. Which goes in the vault?" % str(DeepStone.skill_of(stone).get("name", "stone"))

func _tint(tone: Color, flourish: bool) -> void:
	## The grade's color takes over the frame, the light and the rays.
	_halo.set("tone", tone)
	_rays.set("tone", tone)
	_lamp.modulate = Color(tone, _lamp.modulate.a)
	var from: Color = _panel_style.border_color
	if not flourish:
		_panel_style.border_color = Color(tone, 0.8)
		_panel_style.shadow_color = Color(tone, 0.3)
		return
	_track(create_tween()).tween_method(func(t: float) -> void:
		_panel_style.border_color = from.lerp(Color(tone, 0.8), t)
		_panel_style.shadow_color = Color(tone, 0.3 * t), 0.0, 1.0, 0.5)
	DeepUi.burst(_root, _stage_centre(), tone, 60, 420.0, 1.1, 7.0)

func _show_choices() -> void:
	_done = true
	_skip.visible = false
	_choices.visible = true
	DeepUi.stagger(_choices.get_children(), 0.0, 0.08, 0.85)

func finish() -> void:
	## Straight to the end: the stone out of its rock, every line read, the choices up.
	if _done:
		return
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_dim.modulate.a = 1.0
	if not _opened:
		_opened = true
		_graded = true
		_view.call("configure", stone)
		if not GemView.headless() and is_inside_tree():
			## Skipped before the rock came off: the moment still gets its light, and the
			## whole appraisal in sound — the light, the grade and a Star if there is one.
			DeepAudio.play("gleam")
			DeepAudio.reveal_stone(stone)
			_gleam.fire(_view.global_position + _view.call("centre_point"), _hue.lightened(0.45), 150.0)
		_title.text = "Appraised"
		_title.add_theme_color_override("font_color", _hue.lightened(0.4))
	if not _graded:
		_graded = true
		DeepAudio.play(DeepSoundBank.grade_sound(str(DeepStone.grade(stone).tier)), {"delay": 0.2})
	_subtitle.text = _question() if not owned.is_empty() else "Out of the rock at last. Here is what the loupe says."
	_view.call("set_spin", 0.45)
	_flash.color.a = 0.0
	_lamp.modulate.a = 0.35
	_lamp.scale = Vector2.ONE
	_rays.modulate.a = 1.0
	if _root.is_inside_tree():
		_rays.set("offset", _stage_centre() - _root.size * 0.5)
	_sheet.show_all()
	_tint(DeepUi.tier_color(str(DeepStone.grade(stone).tier)), false)
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

func _input(event: InputEvent) -> void:
	## Anything skips while it is being read; once it has been, only Escape means anything,
	## and it takes the gentlest way out. Nothing reaches the screen underneath.
	if not is_instance_valid(_root) or is_queued_for_deletion() or _closing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not _done:
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
				finish()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_dismiss()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not _done:
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

func _stage_centre() -> Vector2:
	return _stage.global_position + _stage.size * 0.5

func _dust(at: Vector2, color: Color, amount: int, speed: float) -> void:
	## Grit off the rock: not light, so drawn as it is, falling.
	if GemView.headless() or not _root.is_inside_tree():
		return
	var grit := CPUParticles2D.new()
	grit.one_shot = true
	grit.explosiveness = 0.95
	grit.amount = amount
	grit.lifetime = 1.0
	grit.texture = DeepUi.dot_texture()
	grit.spread = 180.0
	grit.direction = Vector2.UP
	grit.initial_velocity_min = speed * 0.35
	grit.initial_velocity_max = speed
	grit.gravity = Vector2(0, 900)
	grit.damping_min = 20.0
	grit.damping_max = 60.0
	grit.scale_amount_min = 0.1
	grit.scale_amount_max = 0.32
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 1.0))
	fade.set_color(1, Color(color.darkened(0.3), 0.0))
	grit.color_ramp = fade
	grit.position = at
	grit.z_index = 20
	_root.add_child(grit)
	grit.emitting = true
	grit.finished.connect(grit.queue_free)

# --- the sheet ---------------------------------------------------------------------------------

class Sheet extends VBoxContainer:
	## What the loupe says about a stone, a line to each thing, and — given the stone of its
	## skill already kept — the same lines for that one beside it, with which is the higher.
	## Every line is laid out from the start with a "?" for its value, so the sheet does not
	## move as it is read; `reveal()` reads one line, `show_all()` the lot.
	const WIDTH := 640.0
	const LABEL_W := 104.0
	const FOUND_W := 262.0
	const OWNED_W := 262.0

	var stone: Dictionary
	var owned: Dictionary
	## Each line by name: {show: [nodes faded in], play: Callable, final: Callable}.
	var _lines: Dictionary = {}
	var _order: Array = []
	## One per compared row: paints the winning value and dims the other. They all fire
	## together on the last line of the sheet, so the verdict lands once, not line by line.
	var _judges: Array = []
	var _tweens: Array = []
	var _name_label: Label

	func _init(found: Dictionary, kept: Dictionary = {}, opts: Dictionary = {}) -> void:
		stone = found
		owned = kept
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 9)
		custom_minimum_size.x = float(opts.get("width", WIDTH))
		var comparing: bool = not owned.is_empty()
		var owned_bits: Array = []
		if comparing:
			var head := DeepUi.hbox(self, 12)
			DeepUi.gap(head, LABEL_W).custom_minimum_size.y = 0
			var found_head := DeepUi.vbox(head, 2)
			found_head.custom_minimum_size.x = FOUND_W
			found_head.size_flags_vertical = Control.SIZE_SHRINK_END
			DeepUi.heading(found_head, "Just found", 13, DeepUi.ACCENT)
			owned_bits.append(found_head)
			var owned_head := DeepUi.hbox(head, 8)
			owned_head.custom_minimum_size.x = OWNED_W
			owned_head.size_flags_vertical = Control.SIZE_SHRINK_END
			## The kept stone's own picture only belongs here when nothing else is showing
			## it: on the Appraise tab it stands beside the sheet at the size the found one
			## does, and a thumbnail of the same stone beside its own column reads as clutter.
			if bool(opts.get("owned_picture", true)):
				StoneCard.mini(owned_head, owned, 44)
			var owned_words := DeepUi.vbox(owned_head, 0)
			owned_words.size_flags_vertical = Control.SIZE_SHRINK_END
			DeepUi.heading(owned_words, "In your vault", 13, DeepUi.INFO)
			DeepUi.label(owned_words, "the one you keep now", 11, DeepUi.DIM)
			owned_bits.append(owned_head)
		## Its name: the skill, what kind it is, and what it does.
		var name_box := DeepUi.vbox(self, 3)
		var name_row := DeepUi.hbox(name_box, 10)
		var skill: Dictionary = DeepStone.skill_of(stone)
		var color_key: String = DeepStone.color(stone)
		_name_label = DeepUi.title(name_row, "?", 30, DeepUi.DIM)
		var tags := DeepUi.hbox(name_row, 6)
		tags.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var rarity: String = str(skill.get("rarity", "COMMON"))
		DeepUi.chip(tags, rarity.capitalize(), StoneCard._rarity_color(rarity), 11, StoneCard.is_mythic(rarity))
		DeepUi.chip(tags, "%s · %s" % [str(DeepContent.color(color_key).get("name", color_key)), str(DeepContent.color(color_key).get("domain", ""))], DeepUi.color(color_key), 11, DeepUi.is_rainbow(color_key))
		var shown: Array = [tags]
		if bool(opts.get("skill_text", false)):
			shown.append(DeepUi.effect_text(name_box, DeepStone.text(stone), 13, DeepUi.MUTED))
		var hue: Color = GemMesh.tint(stone).lightened(0.35)
		var skill_name: String = str(skill.get("name", stone.get("skill", "")))
		var named := func() -> void:
			_name_label.text = skill_name
			_name_label.add_theme_color_override("font_color", hue)
		var say_name := func() -> void:
			named.call()
			_pop(_name_label, 1.45)
			DeepAudio.play(DeepSoundBank.gem_sound(color_key))
		_line("name", shown, say_name, named)
		DeepUi.rule(self, Color(DeepUi.LINE, 0.6))
		## The four C's, less the one already said.
		var carat: int = int(stone.get("carat", 1))
		var cut: int = int(stone.get("cut", 0))
		var clarity: int = int(stone.get("clarity", 3))
		_row("carat", "carat", "Carat", "%d ct", carat, float(carat) / float(DeepStone.carat_max()),
			"%d ct" % int(owned.get("carat", 0)), carat - int(owned.get("carat", 0)), false, owned_bits)
		_row("cut", "cut", "Cut", DeepContent.cut_name(cut), -1, float(cut + 1) / 5.0,
			DeepContent.cut_name(int(owned.get("cut", 0))), cut - int(owned.get("cut", 0)), false, owned_bits)
		_row("clarity", "clarity", "Clarity", DeepContent.clarity_name(clarity), -1, float(clarity + 1) / 6.0,
			DeepContent.clarity_name(int(owned.get("clarity", 3))),
			clarity - int(owned.get("clarity", 3)), true, owned_bits, {"owned_inclusions": owned.get("inclusions", [])})
		## Whatever is frozen inside, announced, then one at a time.
		var inside: Array = stone.get("inclusions", [])
		if not inside.is_empty():
			var block := DeepUi.panel(self, Color(DeepUi.INFO, 0.06), Color(DeepUi.INFO, 0.3), 10, 10)
			var block_box := DeepUi.vbox(block, 7)
			var announce := DeepUi.pill(block_box, "spark", "%s inside!" % DeepUi.plural(inside.size(), "inclusion"), DeepUi.INFO, 14)
			announce.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_line("inclusions", [block, announce], func() -> void:
				_pop(announce, 1.35)
				DeepAudio.play("oddity", {"volume": 0.8}), Callable())
			for index in range(inside.size()):
				var key: String = str(inside[index])
				var inclusion: Dictionary = DeepContent.inclusion(key)
				var cls: String = str(inclusion.get("class", "PINPOINT"))
				var tone: Color = StoneCard.INCLUSION_TONES.get(cls, DeepUi.INFO)
				var line := DeepUi.hbox(block_box, 10)
				var chip := DeepUi.pill(line, str(StoneCard.INCLUSION_GLYPHS.get(cls, "spark")), str(inclusion.get("name", key)), tone, 13)
				chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				var words := DeepUi.wrap(line, str(inclusion.get("text", "")), 13, DeepUi.PAPER)
				words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_line("inclusion:%d" % index, [line], func() -> void:
					_pop(chip, 1.3)
					DeepAudio.play("star" if cls == "STAR" else "stone_found", {"volume": 0.8}), Callable())
		DeepUi.rule(self, Color(DeepUi.LINE, 0.6))
		## Last, what it all adds up to.
		var grade: Dictionary = DeepStone.grade(stone)
		var owned_grade: Dictionary = DeepStone.grade(owned) if comparing else {}
		_row("grade", "star", "Grade", "%d", int(grade.score), -1.0,
			"%d" % int(owned_grade.get("score", 0)), int(grade.score) - int(owned_grade.get("score", 0)), false, owned_bits,
			{"grade": grade, "owned_grade": owned_grade})
		var worth: int = DeepStone.value(stone)
		var owned_worth: int = DeepStone.value(owned) if comparing else 0
		_row("worth", "coin", "Worth", "%d gold", worth, -1.0, "%d gold" % owned_worth, worth - owned_worth, false, owned_bits)
		if comparing:
			var weigh := func() -> void:
				DeepAudio.play("ui_toggle", {"volume": 0.8})
				var delay: float = 0.1
				for judge in _judges:
					(judge as Callable).call()
				for bit in owned_bits:
					_pop_later(bit, delay)
					delay += 0.06
			var weighed := func() -> void:
				for judge in _judges:
					(judge as Callable).call()
			_line("compare", owned_bits, weigh, weighed)
		for name in _order:
			for node in _lines[name].show:
				(node as CanvasItem).modulate.a = 0.0

	func parts() -> Array:
		return _order.duplicate()

	func name_point() -> Vector2:
		return _name_label.global_position + _name_label.size * 0.5

	func _line(name: String, shown: Array, play: Callable, final: Callable) -> void:
		_order.append(name)
		_lines[name] = {"show": shown, "play": play, "final": final}

	func _row(name: String, glyph: String, title: String, format: String, count: int, share: float, owned_text: String,
			delta: int, neutral: bool, owned_bits: Array, extra: Dictionary = {}) -> void:
		## One line: its name, the found stone's value (counted up when `count` is not -1,
		## else `format` is the words), a meter, and the kept stone's value beside it.
		##
		## Beside a kept stone the two columns are built out of the same parts at the same
		## sizes — the same type, the same grade pill, the same inclusion chips — so the eye
		## compares the stones and not the typography. Which one is ahead is said by colouring
		## the winning value and dimming the other, rather than by an arrow the reader has to
		## translate into "higher than the thing beside it".
		var grade: Dictionary = extra.get("grade", {})
		var owned_grade: Dictionary = extra.get("owned_grade", {})
		var comparing: bool = not owned.is_empty()
		var row := DeepUi.hbox(self, 12)
		var head := DeepUi.hbox(row, 8)
		head.custom_minimum_size.x = LABEL_W
		DeepUi.icon(head, glyph, 20, DeepUi.ACCENT, GemIcons.hint(glyph))
		DeepUi.label(head, title, 15, DeepUi.MUTED)
		var cell := DeepUi.hbox(row, 8)
		cell.custom_minimum_size.x = FOUND_W
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var value := DeepUi.title(cell, "?", 22, DeepUi.DIM)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if not comparing:
			value.custom_minimum_size.x = 100
		var words: String = (format % count) if count >= 0 else format
		var badge: Control = null
		if not grade.is_empty():
			badge = DeepUi.pill(cell, "star", str(grade.name), DeepUi.tier_color(str(grade.tier)), 14, "Grade %d of 100" % int(grade.score))
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.modulate.a = 0.0
		## A meter says how far up its scale a value is. It is only drawn when there is
		## nothing to compare against: between two columns it would read as the kept one's.
		var meter: Control = null
		if share >= 0.0 and not comparing:
			DeepUi.spacer(cell)
			meter = DeepUi.bar(cell, 8.0, DeepUi.ACCENT, Color(DeepUi.LINE, 0.7))
			meter.custom_minimum_size = Vector2(80, 8)
			meter.size_flags_horizontal = Control.SIZE_SHRINK_END
			meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			meter.call("set_values", 0.0)
		var theirs: Label = null
		if comparing:
			var their_cell := DeepUi.hbox(row, 8)
			their_cell.custom_minimum_size.x = OWNED_W
			their_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			theirs = DeepUi.title(their_cell, owned_text, 22, DeepUi.PAPER)
			theirs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			theirs.mouse_filter = Control.MOUSE_FILTER_PASS
			if not owned_grade.is_empty():
				var their_badge := DeepUi.pill(their_cell, "star", str(owned_grade.get("name", "")), DeepUi.tier_color(str(owned_grade.get("tier", "ROUGH"))), 14,
					"Grade %d of 100" % int(owned_grade.get("score", 0)))
				their_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			## What the kept stone carries frozen inside it, as marks. The found one's are
			## read out one at a time in their own block below: this is the other column of
			## the same line, so the reader can see at a glance what they would be giving up.
			for key in extra.get("owned_inclusions", []):
				var inclusion: Dictionary = DeepContent.inclusion(str(key))
				var cls: String = str(inclusion.get("class", "PINPOINT"))
				var chip := DeepUi.pill(their_cell, str(StoneCard.INCLUSION_GLYPHS.get(cls, "spark")), "",
					StoneCard.INCLUSION_TONES.get(cls, DeepUi.INFO), 12,
					"%s: %s" % [str(inclusion.get("name", key)), str(inclusion.get("text", ""))])
				chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			owned_bits.append(their_cell)
		## Which of the two is ahead, said in colour once both values are on the page. A
		## clarity is neither better nor worse for being further from Clear, so that row
		## never picks a winner.
		var judge := func() -> void:
			if theirs == null:
				return
			var said: String = "The same as the one in your vault"
			if neutral:
				said = "Clearer than yours" if delta > 0 else ("Cloudier than yours" if delta < 0 else said)
			elif delta > 0:
				said = "Better than the one in your vault"
			elif delta < 0:
				said = "Worse than the one in your vault"
			value.tooltip_text = said
			value.mouse_filter = Control.MOUSE_FILTER_PASS
			theirs.tooltip_text = said
			if neutral or delta == 0:
				value.add_theme_color_override("font_color", DeepUi.PAPER)
				theirs.add_theme_color_override("font_color", DeepUi.PAPER)
				return
			value.add_theme_color_override("font_color", DeepUi.GOOD if delta > 0 else DeepUi.MUTED)
			theirs.add_theme_color_override("font_color", DeepUi.MUTED if delta > 0 else DeepUi.GOOD)
		if comparing:
			_judges.append(judge)
		var settle := func() -> void:
			value.text = words
			value.add_theme_color_override("font_color", DeepUi.PAPER)
			if meter != null:
				meter.call("set_values", clampf(share, 0.0, 1.0))
			if badge != null:
				badge.modulate.a = 1.0
			judge.call()
		_line(name, [], func() -> void:
			value.add_theme_color_override("font_color", DeepUi.PAPER)
			if count >= 0:
				## Counted up, a tick of the pen as it goes, landing with a thump.
				var ticks: Array = [0]
				var up := value.create_tween()
				_tweens.append(up)
				var seconds: float = 0.95 if not grade.is_empty() else 0.5
				up.tween_method(func(v: float) -> void:
					var shown_count: int = int(round(v))
					value.text = format % shown_count
					if shown_count - int(ticks[0]) >= maxi(1, count / 8):
						ticks[0] = shown_count
						DeepAudio.play("tally", {"volume": 0.55, "gap": 0.03}), 0.0, float(count), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				up.tween_callback(func() -> void:
					value.text = words
					_pop(value, 1.3)
					if badge != null:
						DeepAudio.play(DeepSoundBank.grade_sound(str(grade.tier)))
						_pop(badge, 1.5)
						badge.modulate.a = 1.0
					elif name == "worth":
						DeepAudio.play("sell", {"volume": 0.6})
					else:
						DeepAudio.play("tally", {"volume": 0.8}))
			else:
				value.text = words
				_pop(value, 1.4)
				DeepAudio.play("tally", {"volume": 0.8})
			if meter != null:
				var fill := value.create_tween()
				_tweens.append(fill)
				fill.tween_method(func(v: float) -> void: meter.call("set_values", v), 0.0, clampf(share, 0.0, 1.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT), settle)

	func reveal(name: String) -> void:
		var line: Dictionary = _lines.get(name, {})
		if line.is_empty():
			return
		for node in line.show:
			var fade := (node as Control).create_tween()
			_tweens.append(fade)
			fade.tween_property(node, "modulate:a", 1.0, 0.25)
		var play: Callable = line.play
		if play.is_valid():
			play.call()

	func show_all() -> void:
		for tween in _tweens:
			if tween != null and tween.is_valid():
				tween.kill()
		_tweens.clear()
		for name in _order:
			var line: Dictionary = _lines[name]
			for node in line.show:
				(node as CanvasItem).modulate.a = 1.0
			var final: Callable = line.final
			if final.is_valid():
				final.call()
		for node in find_children("*", "Control", true, false):
			(node as Control).scale = Vector2.ONE

	func _pop(control: Control, strength: float) -> void:
		if DeepUi.headless() or not control.is_inside_tree():
			return
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2.ONE * strength
		var tween := control.create_tween()
		_tweens.append(tween)
		tween.tween_property(control, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _pop_later(control: Control, delay: float) -> void:
		var tween := control.create_tween()
		_tweens.append(tween)
		tween.tween_interval(delay)
		tween.tween_property(control, "modulate:a", 1.0, 0.01)
		tween.tween_callback(func() -> void: _pop(control, 1.6))

# --- the light -----------------------------------------------------------------------------------

class Gleam extends Control:
	## The flare when the last of the rock comes away: a bloom, a star of light with long
	## arms, a streak across the lens and a chain of ghosts through its middle. Afterwards the
	## stone keeps catching the light now and then, a glint at a time.
	const LIFE := 1.7
	const GHOSTS: Array = [[0.45, 34.0, 0.16], [0.8, 18.0, 0.22], [1.15, 58.0, 0.1], [1.5, 26.0, 0.18], [1.95, 80.0, 0.08]]
	var tone: Color = Color.WHITE
	var at: Vector2 = Vector2.ZERO
	var reach: float = 0.0
	var _age: float = 99.0
	var _clock: float = 0.0
	var _next_glint: float = 0.6
	var _glints: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		set_process(false)

	func fire(point: Vector2, color: Color, glint_reach: float) -> void:
		at = point
		tone = color
		reach = glint_reach
		_age = 0.0
		set_process(true)

	func _process(delta: float) -> void:
		_age += delta
		_clock += delta
		if reach > 0.0 and _age > LIFE * 0.6:
			_next_glint -= delta
			if _next_glint <= 0.0:
				_next_glint = randf_range(0.7, 1.5)
				var angle: float = randf_range(0.0, TAU)
				_glints.append({"at": at + Vector2.from_angle(angle) * randf_range(0.1, 0.8) * reach, "age": 0.0, "size": randf_range(18.0, 34.0)})
		for glint in _glints:
			glint.age += delta
		_glints = _glints.filter(func(g: Dictionary) -> bool: return float(g.age) < 0.5)
		queue_redraw()

	func _draw() -> void:
		var glow: Texture2D = DeepUi.glow_texture()
		if _age < LIFE:
			var rise: float = clampf(_age / 0.12, 0.0, 1.0)
			var power: float = rise * pow(1.0 - _age / LIFE, 1.6)
			var bloom: float = 620.0 * (0.55 + 0.45 * rise)
			draw_texture_rect(glow, Rect2(at - Vector2(bloom, bloom) * 0.5, Vector2(bloom, bloom)), false, Color(tone, 0.5 * power))
			var core: float = 200.0
			draw_texture_rect(glow, Rect2(at - Vector2(core, core) * 0.5, Vector2(core, core)), false, Color(1, 1, 1, 0.9 * power))
			## The streak the lens throws sideways.
			var streak := Vector2(size.x * (0.5 + 0.9 * rise), 18.0)
			draw_texture_rect(glow, Rect2(at - streak * 0.5, streak), false, Color(tone.lightened(0.4), 0.55 * power))
			var hair := Vector2(size.x * 1.6, 5.0)
			draw_texture_rect(glow, Rect2(at - hair * 0.5, hair), false, Color(1, 1, 1, 0.5 * power))
			## A star of light: four long arms and four short, turning slowly.
			_star(at, 420.0 * (0.55 + 0.45 * rise), 9.0, _clock * 0.22, Color(1, 1, 1, 0.8 * power), 4)
			_star(at, 230.0 * (0.55 + 0.45 * rise), 6.0, _clock * 0.22 + PI * 0.25, Color(tone.lightened(0.5), 0.6 * power), 4)
			## Ghosts on the line from the flare through the middle of the lens.
			var axis: Vector2 = size * 0.5 - at
			for index in range(GHOSTS.size()):
				var ghost: Array = GHOSTS[index]
				var place: Vector2 = at + axis * float(ghost[0])
				var radius: float = float(ghost[1])
				var tint: Color = tone.lerp(Color(0.6, 0.8, 1.0), 0.25 * float(ghost[0]))
				if index % 2 == 0:
					draw_texture_rect(glow, Rect2(place - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(tint, float(ghost[2]) * power))
				else:
					var hexagon := PackedVector2Array()
					for corner in range(6):
						hexagon.append(place + Vector2.from_angle(TAU * float(corner) / 6.0 + 0.3) * radius)
					draw_colored_polygon(hexagon, Color(tint, float(ghost[2]) * 0.6 * power))
		for glint in _glints:
			var shine: float = sin(float(glint.age) / 0.5 * PI)
			_star(glint.at, float(glint.size) * shine, 2.0, 0.3, Color(1, 1, 1, 0.9 * shine), 4)
			var dot: float = float(glint.size) * 0.7 * shine
			draw_texture_rect(glow, Rect2(glint.at - Vector2(dot, dot) * 0.5, Vector2(dot, dot)), false, Color(tone, 0.8 * shine))

	func _star(centre: Vector2, length: float, width: float, turn: float, color: Color, arms: int) -> void:
		## Arms that taper to nothing: bright at the heart, gone at the tips.
		if length <= 0.5 or color.a <= 0.002:
			return
		var clear := Color(color, 0.0)
		for index in range(arms):
			var direction := Vector2.from_angle(turn + TAU * float(index) / float(arms))
			var side: Vector2 = direction.orthogonal() * width
			draw_polygon(PackedVector2Array([centre + side, centre + direction * length, centre - side]),
				PackedColorArray([color, clear, color]))
