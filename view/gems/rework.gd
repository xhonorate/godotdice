extends Control
## A stone reworked: its Cut or its Clarity read off a ladder of rungs. The stone is worked
## first (in the Oven it heats from red to white-hot, on the Wheel it throws sparks) while the
## ladder flickers like a reel and slows; then a held beat with the ladder dark; then the rung
## lands with a flash, and a flourish as big as the result is good: a dull puff for a worse
## rung, a chime for a better one, and a shower of the grade's color and a jackpot for the top
## of the ladder. A stone that does not survive shakes the ladder and flies apart in shards.
## A tap or a click on it skips straight to the landing.
## Used by the Market's Wheel and Oven, and wherever down the mine a Cut or a Clarity changes.

const Thumbs = preload("res://view/gems/thumbs.gd")
const Shatter = preload("res://view/gems/shatter.gd")

signal finished

## How long the work runs before the beat, and how long the beat holds, in seconds.
const BUILD_SECONDS: float = 1.15
const BEAT_SECONDS: float = 0.42

var stone: Dictionary
var kind: String = "cut"
var _rungs: Array = []
var _lit: int = -1
var _was: int = -1
var _picture: Control
var _holder: Control
var _heat_glow: Control
var _ladder: HBoxContainer
var _line: Label
var _flicker: Tween = null
var _done: bool = false
## Set by settle(): lands without a sound, a shake or a burst, for a page built again.
var _quiet: bool = false
## While it plays: where it lands, and how hot the stone is (0 cold, 1 white-hot) and how
## bright the landing's flash still is, both drawn behind the stone.
var _playing: bool = false
var _now: int = 0
var _broke: bool = false
var _heat: float = 0.0
var _flash: float = 0.0
var _flash_tone: Color = Color.WHITE

func _init(new_stone: Dictionary, which: String, edge: float = 120.0, beside: bool = false) -> void:
	## `beside` stands the stone to the left of the ladder rather than over it, for a page with
	## more width than height to spare (a result page on the phone).
	stone = new_stone
	kind = which
	_was = int(stone.get(kind, 0))
	_lit = _was
	mouse_filter = Control.MOUSE_FILTER_PASS
	var outer: BoxContainer = HBoxContainer.new() if beside else VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var column: BoxContainer = outer
	## The room the stone stands in: its edge at least, and whatever height the ladder is given
	## past that (the Market's column gives it plenty), with the stone in its middle. A heavy
	## stone is drawn well past its edge and needs the room.
	_holder = Control.new()
	_holder.custom_minimum_size = Vector2(edge, edge)
	_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_holder)
	if beside:
		column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(column)
	## The heat and the flash, behind the stone and spilling well past it.
	_heat_glow = Control.new()
	_heat_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heat_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_glow.draw.connect(_draw_heat)
	_holder.add_child(_heat_glow)
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
	var names: Array = _names()
	for index in range(names.size()):
		var rung := Rung.new(str(names[index].get("name", index)), index == _was, index)
		_ladder.add_child(rung)
		_rungs.append(rung)
	_line = DeepUi.label(column, "", 18, DeepUi.ACCENT_HI, HORIZONTAL_ALIGNMENT_CENTER)
	_line.add_theme_font_override("font", DeepUi.display_font())
	if beside:
		custom_minimum_size = Vector2(edge + 12.0 + (Rung.edge().x + 6.0) * names.size(), maxf(edge, Rung.edge().y + float(DeepUi.readable(18)) + 16.0))
	elif DeepUi.phone:
		custom_minimum_size = Vector2(maxf(edge, (Rung.edge().x + 6.0) * names.size()), edge + Rung.edge().y + float(DeepUi.readable(18)) + 30.0)
	else:
		custom_minimum_size = Vector2(maxf(edge, 70.0 * names.size()), edge + 90.0)
	_light(_was)

func _names() -> Array:
	return DeepContent.cuts() if kind == "cut" else DeepContent.clarities()

func _light(index: int) -> void:
	_lit = index
	for i in range(_rungs.size()):
		_rungs[i].lit = i <= index if kind == "cut" else i == index
		_rungs[i].queue_redraw()

func quality(rung: int) -> float:
	## How good a rung is, 0 to 1: a Cut by how high it stands; a Clarity by how far it sits
	## from Clear on its own side, so Flawless and Intricate are both the top.
	var count: int = _names().size()
	if kind == "cut":
		return float(rung) / float(maxi(1, count - 1))
	var clear: int = DeepContent.clear_index()
	var reach: int = maxi(1, (count - 1 - clear) if rung > clear else clear)
	return clampf(float(absi(rung - clear)) / float(reach), 0.0, 1.0)

func play(now: int, broke: bool) -> void:
	## The work, the beat, the landing. Tap or click to skip to the landing.
	_now = now
	_broke = broke
	if DeepUi.headless() or not is_inside_tree():
		_land(now, broke)
		return
	_playing = true
	_holder.pivot_offset = _holder.size * 0.5
	pivot_offset = size * 0.5
	var oven: bool = kind == "clarity"
	if oven:
		DeepAudio.play("flame", {"volume": 0.75})
	else:
		DeepAudio.play("loupe_spin", {"volume": 0.7})
	var t := create_tween()
	_flicker = t
	## The work: the stone heats (or grinds) while the rungs flicker, quick then slowing.
	t.tween_method(_set_heat, 0.0, 1.0, BUILD_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var reel := create_tween()
	var steps: int = 12
	var spent: float = 0.0
	for i in range(steps):
		var gap: float = 0.045 + 0.0105 * float(i)
		spent += gap
		reel.tween_callback(func() -> void:
			if _done:
				return
			_light(randi_range(0, _rungs.size() - 1))
			DeepAudio.play("ui_tap", {"volume": 0.3, "gap": 0.0}))
		reel.tween_interval(gap)
		if i % 2 == 1:
			reel.tween_callback(func() -> void:
				if _done:
					return
				DeepUi.shake(_holder, 1.5 + 5.0 * _heat, 0.12)
				_sparks(oven))
	## The beat: the ladder goes dark and the stone hangs at its hottest, one heartbeat.
	t.tween_callback(func() -> void:
		if _done:
			return
		if reel.is_valid():
			reel.kill()
		_light(-1)
		DeepAudio.play("reel_tick", {"volume": 0.55}))
	t.tween_method(_set_heat, 1.0, 1.12, BEAT_SECONDS).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: _land(now, broke))

func _set_heat(value: float) -> void:
	_heat = value
	## In the Oven the stone itself glows: red, then orange, then near white. On the Wheel it
	## only brightens under the sparks.
	var h: float = clampf(value, 0.0, 1.0)
	if kind == "clarity":
		_picture.modulate = Color(1.0 + 0.45 * h, 1.0 + 0.05 * h - 0.25 * h * (1.0 - h) * 2.0, 1.0 - 0.35 * h, 1.0)
	else:
		_picture.modulate = Color(1.0 + 0.25 * h, 1.0 + 0.25 * h, 1.0 + 0.3 * h, 1.0)
	_heat_glow.queue_redraw()

func _sparks(oven: bool) -> void:
	if not is_inside_tree():
		return
	var centre: Vector2 = _holder.position + _holder.size * 0.5
	if oven:
		## Embers off a hot stone: few, slow, orange.
		DeepUi.burst(self, centre, Color("ff9a3c").lerp(Color("ffe2a0"), _heat), int(5 + 8 * _heat), 90.0 + 90.0 * _heat, 0.55, 3.5)
	else:
		## The wheel biting: a quick spray of pale sparks.
		DeepUi.burst(self, centre + Vector2(0, _holder.size.y * 0.3), Color("ffe6b0"), int(8 + 10 * _heat), 260.0, 0.3, 2.5)

func _draw_heat() -> void:
	var size: Vector2 = _heat_glow.size
	var centre: Vector2 = size * 0.5
	var edge: float = minf(size.x, size.y)
	var texture: Texture2D = DeepUi.glow_texture()
	if _heat > 0.001:
		var h: float = clampf(_heat, 0.0, 1.12)
		var tone: Color = Color("c8341c").lerp(Color("ff9a3c"), clampf(h * 1.4, 0.0, 1.0)).lerp(Color("fff1c8"), clampf((h - 0.6) * 2.0, 0.0, 1.0)) if kind == "clarity" else Color("bcd6ff").lerp(Color("fff4dc"), h)
		var reach: float = edge * (0.9 + 0.55 * h)
		_heat_glow.draw_texture_rect(texture, Rect2(centre - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), false, Color(tone, 0.75 * minf(h, 1.0)))
	if _flash > 0.001:
		var reach: float = edge * (0.8 + 1.4 * (1.0 - _flash))
		_heat_glow.draw_texture_rect(texture, Rect2(centre - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), false, Color(_flash_tone, _flash))

func _gui_input(event: InputEvent) -> void:
	## A tap or a click on the ladder skips the work and the beat: it lands at once.
	if not _playing or _done:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		skip(_now, _broke)
		accept_event()

func skip(now: int, broke: bool) -> void:
	if _flicker != null and _flicker.is_valid():
		_flicker.kill()
	_land(now, broke)

func settle(now: int, broke: bool) -> void:
	## Shown already landed, as it was the first time, without making a sound of it again.
	_quiet = true
	_land(now, broke)

func _cool() -> void:
	## The heat goes out of the stone and the flash fades, after the landing.
	if not is_inside_tree() or DeepUi.headless():
		_set_heat(0.0)
		_flash = 0.0
		return
	var t := create_tween().set_parallel(true)
	t.tween_method(_set_heat, minf(_heat, 1.0), 0.0, 0.7).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void:
		_flash = v
		_heat_glow.queue_redraw(), _flash, 0.0, 0.85).set_ease(Tween.EASE_OUT)

func _land(now: int, broke: bool) -> void:
	if _done:
		return
	_done = true
	_playing = false
	if broke:
		_light(-1)
		_picture.visible = false
		_set_heat(0.0)
		var shards := Shatter.new(stone, _holder.custom_minimum_size.x, 0.0, not _quiet)
		shards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_holder.add_child(shards)
		if not _quiet:
			DeepUi.shake(self, 8.0, 0.4)
			DeepAudio.play("gem_shatter", {"volume": 0.9})
			DeepAudio.play("ui_deny", {"delay": 0.25, "volume": 0.6})
		_line.text = "It shattered. %s is gone." % DeepUi.skill_name(stone)
		_line.add_theme_color_override("font_color", DeepUi.BAD)
		finished.emit()
		return
	_light(now)
	var names: Array = _names()
	var gain: float = quality(now) - quality(_was)
	var top: bool = quality(now) >= 0.999
	var arrow: String = "▲" if gain > 0.001 else ("▼" if gain < -0.001 else "◆")
	_line.text = "%s: %s → %s %s" % ["Cut" if kind == "cut" else "Clarity", str(names[_was].get("name", "")), str(names[now].get("name", "")), arrow]
	var tone: Color = DeepUi.GOOD if gain > 0.001 else (DeepUi.BAD if gain < -0.001 else DeepUi.MUTED)
	_line.add_theme_color_override("font_color", tone)
	if _quiet:
		_set_heat(0.0)
		finished.emit()
		return
	_flourish(gain, top)
	DeepUi.pulse(_line, 1.25 if gain > 0.001 else 1.12, 0.5)
	_cool()
	finished.emit()

func _flourish(gain: float, top: bool) -> void:
	## As loud as the result is good. Worse: a dull flash and a puff of ash. Level: a soft
	## chime. Better: a flash, a chime and a spray of light, wider the further it climbed. The
	## top of the ladder: all of that in the grade's color, a jackpot and the ladder shaken.
	var centre: Vector2 = _holder.position + _holder.size * 0.5
	var tier_tone: Color = DeepUi.tier_color(str(DeepStone.grade(_with(_now)).tier))
	var live: bool = is_inside_tree() and not DeepUi.headless()
	if gain < -0.001:
		_flash_tone = Color("8a8f9c")
		_flash = 0.35
		DeepAudio.play("salvage_lose", {"volume": 0.7})
		DeepAudio.play("ui_deny", {"volume": 0.5, "delay": 0.08})
		if live:
			DeepUi.burst(self, centre, Color("6b6f7a"), 18, 110.0, 0.8, 4.0)
		return
	if gain <= 0.001:
		_flash_tone = DeepUi.PAPER
		_flash = 0.45
		DeepAudio.play("ui_toggle", {"volume": 0.8})
		DeepAudio.play("gleam", {"volume": 0.45})
		if live:
			DeepUi.burst(self, centre, DeepUi.PAPER, 20, 180.0, 0.7, 4.0)
		return
	_flash_tone = tier_tone.lightened(0.35) if top else DeepUi.ACCENT_HI
	_flash = 1.0 if top else 0.7 + 0.3 * clampf(gain, 0.0, 1.0)
	DeepAudio.play("gleam")
	DeepAudio.play("unlock", {"delay": 0.1, "volume": 0.6})
	if gain >= 0.4 or top:
		DeepAudio.play(DeepSoundBank.grade_sound(str(DeepStone.grade(_with(_now)).tier)), {"delay": 0.15, "volume": 0.8})
	if top:
		DeepAudio.play("jackpot", {"delay": 0.2, "volume": 0.75})
	if not live:
		return
	var amount: int = int(40 + 90 * clampf(gain, 0.0, 1.0))
	DeepUi.burst(self, centre, DeepUi.ACCENT_HI, amount, 300.0 + 200.0 * gain, 1.0, 6.0)
	if gain >= 0.4 or top:
		DeepUi.burst(self, centre, tier_tone, amount / 2, 220.0, 1.3, 7.0)
		DeepUi.shake(self, 3.0 + (5.0 if top else 0.0), 0.35)
	if top:
		var again := func() -> void:
			if is_instance_valid(self) and is_inside_tree():
				DeepUi.burst(self, centre, tier_tone.lightened(0.3), 90, 520.0, 1.4, 8.0)
		get_tree().create_timer(0.22).timeout.connect(again)

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
	## On the phone the names take turns over and under the bars, so each has two rungs'
	## width to read at the text floor in.
	var above: bool = false
	static func edge() -> Vector2:
		## A rung's size: on the phone in points, so its name reads at the text floor.
		return Vector2(DeepUi.pt(42), DeepUi.pt(36)) if DeepUi.phone else Vector2(64, 30)
	func _init(text: String, start: bool, index: int = 0) -> void:
		words = text
		was = start
		above = DeepUi.phone and index % 2 == 1
		custom_minimum_size = edge()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var bar := Rect2(Vector2(4, 2), Vector2(size.x - 8, 8))
		if DeepUi.phone:
			bar = Rect2(Vector2(3, size.y * 0.5 - DeepUi.pt(2.5)), Vector2(size.x - 6, DeepUi.pt(5)))
		draw_style_box(DeepUi.flat(DeepUi.ACCENT_HI if lit else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 3, 0), bar)
		if lit:
			draw_texture_rect(DeepUi.glow_texture(), bar.grow(10), false, Color(DeepUi.ACCENT, 0.35))
		if was:
			draw_rect(bar.grow(3), Color(DeepUi.MUTED, 0.6), false, 1.0)
		var font: Font = DeepUi.body_font()
		var font_size: int = DeepUi.readable(11) if DeepUi.phone else 12
		var width: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline: float = size.y - 3.0
		if DeepUi.phone:
			baseline = bar.position.y - DeepUi.pt(3) if above else size.y - DeepUi.pt(1)
		draw_string(font, Vector2((size.x - width) * 0.5, baseline), words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DeepUi.ACCENT_HI if lit else DeepUi.MUTED)
