extends Control
## A stone reworked: its Cut or its Clarity read off a ladder of rungs that flickers like a reel
## for about a second, then lands. A better rung gets a flash and a rising chime, a worse one a
## short low note. A stone that does not survive shakes the ladder and flies apart in shards.
## Used by the Market's Wheel and Oven, and wherever down the mine a Cut or a Clarity changes.

const Thumbs = preload("res://view/gems/thumbs.gd")
const Shatter = preload("res://view/gems/shatter.gd")

signal finished

var stone: Dictionary
var kind: String = "cut"
var _rungs: Array = []
var _lit: int = -1
var _was: int = -1
var _picture: Control
var _holder: Control
var _ladder: HBoxContainer
var _line: Label
var _flicker: Tween = null
var _done: bool = false
## Set by settle(): lands without a sound, a shake or a burst, for a page built again.
var _quiet: bool = false

func _init(new_stone: Dictionary, which: String, edge: float = 120.0) -> void:
	stone = new_stone
	kind = which
	_was = int(stone.get(kind, 0))
	_lit = _was
	mouse_filter = Control.MOUSE_FILTER_PASS
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	## The room the stone stands in: its edge at least, and whatever height the ladder is given
	## past that (the Market's column gives it plenty), with the stone in its middle. A heavy
	## stone is drawn well past its edge and needs the room.
	_holder = Control.new()
	_holder.custom_minimum_size = Vector2(edge, edge)
	_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_holder)
	_picture = Thumbs.GemThumb.new(stone, edge)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.anchor_left = 0.5
	_picture.anchor_right = 0.5
	_picture.anchor_top = 0.5
	_picture.anchor_bottom = 0.5
	_picture.offset_left = -edge * 0.5
	_picture.offset_right = edge * 0.5
	_picture.offset_top = -edge * 0.5
	_picture.offset_bottom = edge * 0.5
	_holder.add_child(_picture)
	_ladder = HBoxContainer.new()
	_ladder.add_theme_constant_override("separation", 6)
	_ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	_ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_ladder)
	var names: Array = DeepContent.cuts() if kind == "cut" else DeepContent.clarities()
	for index in range(names.size()):
		var rung := Rung.new(str(names[index].get("name", index)), index == _was)
		_ladder.add_child(rung)
		_rungs.append(rung)
	_line = DeepUi.label(column, "", 18, DeepUi.ACCENT_HI, HORIZONTAL_ALIGNMENT_CENTER)
	_line.add_theme_font_override("font", DeepUi.display_font())
	custom_minimum_size = Vector2(maxf(edge, 70.0 * names.size()), edge + 90.0)
	_light(_was)

func _light(index: int) -> void:
	_lit = index
	for i in range(_rungs.size()):
		_rungs[i].lit = i <= index if kind == "cut" else i == index
		_rungs[i].queue_redraw()

func play(now: int, broke: bool) -> void:
	## The reel: rungs flicker at random, slowing, then land on `now` (or, broken, go dark).
	if DeepUi.headless() or not is_inside_tree():
		_land(now, broke)
		return
	DeepAudio.play("loupe_spin", {"volume": 0.7})
	var steps: int = 14
	var t := create_tween()
	_flicker = t
	for i in range(steps):
		var gap: float = 0.05 + 0.012 * float(i)
		t.tween_callback(func() -> void:
			_light(randi_range(0, _rungs.size() - 1))
			DeepAudio.play("ui_tap", {"volume": 0.35, "gap": 0.0}))
		t.tween_interval(gap)
		if i % 3 == 0:
			t.tween_callback(func() -> void: DeepUi.shake(_holder, 2.5, 0.12))
	t.tween_callback(func() -> void: _land(now, broke))

func skip(now: int, broke: bool) -> void:
	if _flicker != null and _flicker.is_valid():
		_flicker.kill()
	_land(now, broke)

func settle(now: int, broke: bool) -> void:
	## Shown already landed, as it was the first time, without making a sound of it again.
	_quiet = true
	_land(now, broke)

func _land(now: int, broke: bool) -> void:
	if _done:
		return
	_done = true
	if broke:
		_light(-1)
		_picture.visible = false
		var shards := Shatter.new(stone, _holder.custom_minimum_size.x, 0.0, not _quiet)
		shards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_holder.add_child(shards)
		if not _quiet:
			DeepUi.shake(self, 8.0, 0.4)
			DeepAudio.play("gem_shatter", {"volume": 0.9})
			DeepAudio.play("ui_deny", {"delay": 0.25, "volume": 0.6})
		_line.text = "It broke. %s is gone." % DeepUi.skill_name(stone)
		_line.add_theme_color_override("font_color", DeepUi.BAD)
		finished.emit()
		return
	_light(now)
	var names: Array = DeepContent.cuts() if kind == "cut" else DeepContent.clarities()
	var better: bool = DeepStone.grade(_with(now)).score >= DeepStone.grade(_with(_was)).score
	_line.text = "%s: %s → %s %s" % ["Cut" if kind == "cut" else "Clarity", str(names[_was].get("name", "")), str(names[now].get("name", "")), "▲" if better else "▼"]
	_line.add_theme_color_override("font_color", DeepUi.GOOD if better else DeepUi.BAD)
	if _quiet:
		finished.emit()
		return
	if better:
		DeepAudio.play("gleam")
		DeepAudio.play("unlock", {"delay": 0.1, "volume": 0.6})
		if is_inside_tree() and not DeepUi.headless():
			DeepUi.burst(self, _holder.position + _holder.size * 0.5, DeepUi.ACCENT_HI, 60, 380.0, 1.0, 7.0)
	else:
		DeepAudio.play("ui_deny", {"volume": 0.7})
	DeepUi.pulse(_line, 1.25, 0.5)
	finished.emit()

func _with(rung: int) -> Dictionary:
	var copy: Dictionary = stone.duplicate(true)
	copy[kind] = rung
	copy.appraised = true
	return copy

class Rung extends Control:
	## One rung of the ladder: a bar that lights, and its name under it.
	var words: String
	var was: bool
	var lit: bool = false
	func _init(text: String, start: bool) -> void:
		words = text
		was = start
		custom_minimum_size = Vector2(64, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var bar := Rect2(Vector2(4, 2), Vector2(size.x - 8, 8))
		draw_style_box(DeepUi.flat(DeepUi.ACCENT_HI if lit else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 3, 0), bar)
		if lit:
			draw_texture_rect(DeepUi.glow_texture(), bar.grow(10), false, Color(DeepUi.ACCENT, 0.35))
		if was:
			draw_rect(bar.grow(3), Color(DeepUi.MUTED, 0.6), false, 1.0)
		var font: Font = DeepUi.body_font()
		var width: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2((size.x - width) * 0.5, 27), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DeepUi.ACCENT_HI if lit else DeepUi.MUTED)
