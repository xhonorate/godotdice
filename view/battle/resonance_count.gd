extends "res://view/battle/tally.gd"
## What Resonance is worth, counted out the way a gem's arithmetic is.
##
## A Birthstone's tiers and the passives that pay on Resonance are where a whole rail's chain
## turns into one number, and a number is only felt if it is seen being made. Each lit tier is
## called out by name, large, and counted on its own: the number Resonance multiplies (the
## tier's own three, the crowns showing, the rerolls left unspent) in the left-hand box, then
## Resonance itself streaming out of the rail's counter as light, every color of it, into a
## box framed in every color, so it is never mistaken for a stone's weight in its gold one.
## The two are fused into the figure and it flies; the screen lands it, then calls the next.
## A tier with no figure (a cleanse, an Encore, the poison ticking) is only called out. The
## Gambler's pot is counted in pyrite: coins out of his purse onto the table, the bank matching
## the pot, the table taking it.
##
## `open_swell` is the other count: a figure that grows for as long as a gem's blows keep
## landing (a Riposte's guard, a Leech's draught), climbing and burning hotter with each, and
## flown to where it lands once the gem has had its say.
##
## The rules decided every number (`DeepBattle.birth_count`) and the beat (`birth_span`); this
## only plays them.

## () -> Control: the rail's Resonance count, which Resonance streams out of.
var flow_from: Callable = Callable()
## () -> Control: where the number Resonance multiplies comes from, when it is not on the dice
## (the reroll button, for Second Wind).
var coef_anchor: Callable = Callable()
## () -> Control: the pot on the Gambler's buffs, and his purse on the strip.
var pot_anchor: Callable = Callable()
var bank_anchor: Callable = Callable()
## (delta: int) -> void: told as pyrite leaves the purse or reaches it, so it reads what the
## coins have done. (value: int) -> void: the pot shows a new figure.
var on_bank: Callable = Callable()
var on_pot: Callable = Callable()

var _count: Dictionary = {}
var _callout: Control = null
## The boxes framed in every color, redrawn as their colors turn, and the numbers in them.
var _rainbows: Array = []
var _res_label: Label = null
var _res_box: PanelContainer = null
## The label last made white for the turning color, by instance id.
var _res_tinted: int = 0
var _hue: float = 0.0
## A swell: how many times it has grown.
var _swells: int = 0
var _burning: bool = false

func _process(delta: float) -> void:
	super(delta)
	_hue = fmod(_hue + delta * 0.35, 1.0)
	for box in _rainbows:
		if is_instance_valid(box):
			(box as Control).queue_redraw()
	if _res_label != null and is_instance_valid(_res_label):
		## Its type is made white once and the turning color laid over it, rather than the
		## label's theme being changed (and its text shaped again) every frame.
		if _res_tinted != _res_label.get_instance_id():
			_res_tinted = _res_label.get_instance_id()
			_res_label.add_theme_color_override("font_color", Color.WHITE)
		_res_label.self_modulate = Color.from_hsv(fmod(_hue + 0.5, 1.0), 0.28, 1.0)

# --- a tier ------------------------------------------------------------------------------------

func play_tier(count: Dictionary) -> void:
	## Counts one lit tier out from now. The plate frees itself once its figure has flown, or
	## once its name has been read if it has none.
	_count = count
	_tally = count
	_numbered = count.has("amount")
	_pace = clampf(float(count.get("pace", 1.0)), 0.0, 1.0)
	_step = start_step
	_build_tier()
	_place()
	_call_out()
	var timeline := create_tween().set_parallel(true)
	if _pace <= 0.0:
		## Counts are off: the name and the figure together, for a moment, then it flies.
		if _numbered:
			timeline.tween_callback(_tier_fuse.bind(true)).set_delay(0.0)
			timeline.tween_callback(_launch).set_delay(DeepBattle.BIRTH_GLANCE)
		else:
			timeline.tween_callback(_fade).set_delay(DeepBattle.BIRTH_GLANCE)
		return
	var at: float = DeepBattle.BIRTH_CALL * _pace
	if not _numbered:
		timeline.tween_callback(_fade).set_delay(at)
		return
	var step: float = DeepBattle.TALLY_STEP * _pace
	var dice: Array = count.get("coef_dice", [])
	if not dice.is_empty():
		var gap: float = DeepBattle.tally_die_gap(dice.size()) * _pace
		for i in range(dice.size()):
			timeline.tween_callback(_crown.bind(str(dice[i]))).set_delay(at + gap * float(i))
		at += gap * float(dice.size() - 1) + DeepBattle.TALLY_FLIGHT * _pace
	elif int(count.get("coef", 1)) != 1 or count.has("base"):
		timeline.tween_callback(_reveal_tier_base.bind(step)).set_delay(at)
		at += step
	if count.has("res"):
		timeline.tween_callback(_flow).set_delay(at)
		at += DeepBattle.BIRTH_FLOW * _pace
	if _pot_mode() in ["double", "all"] and count.has("base"):
		timeline.tween_callback(_bank_in.bind(step)).set_delay(at)
		at += step
	if bool(count.get("half", false)):
		timeline.tween_callback(_halve).set_delay(at)
		at += step
	timeline.tween_callback(_tier_fuse.bind(false)).set_delay(at)
	at += DeepBattle.TALLY_FUSE * _pace
	if not str(count.get("repeat_die", "")).is_empty():
		timeline.tween_callback(_repeat_in.bind(step)).set_delay(at)
		at += step
	for entry in count.get("adds", []):
		timeline.tween_callback(_add.bind(entry, step)).set_delay(at)
		at += step
	timeline.tween_callback(_launch).set_delay(at)

func _pot_mode() -> String:
	return str(_count.get("pot", {}).get("mode", ""))

func _build_tier() -> void:
	var kind: String = str(_count.get("kind", ""))
	var look: Array = kind_look(kind)
	_kind_tone = look[1]
	_column = DeepUi.vbox(self, 2)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	## The tier's name, large, and under it what earned it.
	var call := DeepUi.vbox(_column, -6 if not compact else -2)
	call.alignment = BoxContainer.ALIGNMENT_CENTER
	_callout = call
	var name_label := DeepUi.title(call, str(_count.get("name", "")), 22 if compact else 52, _bright(color), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.96))
	name_label.add_theme_constant_override("outline_size", 6 if compact else 14)
	name_label.add_theme_color_override("font_shadow_color", Color(color, 0.55))
	name_label.add_theme_constant_override("shadow_offset_y", 3)
	var line: String = tier_line(_count)
	if not line.is_empty() and not compact:
		var said := DeepUi.heading(call, line, 14, _bright(color).lightened(0.3))
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		said.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
		said.add_theme_constant_override("outline_size", 5)
	if not _numbered:
		return
	var big: int = 18 if compact else 30
	_row = DeepUi.hbox(_column, 6)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var single: bool = _count.has("res") and int(_count.get("coef", 1)) == 1
	if single:
		## Resonance alone is the figure: it streams straight into the box that lands.
		_base_box = _rainbow_box(_row)
		_res_box = _base_box
		var base_row := DeepUi.hbox(_base_box, 4)
		DeepUi.icon(base_row, str(look[0]), 16.0 if compact else 26.0, _kind_tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_base_label = _number(base_row, "0", big, DeepUi.PAPER)
		_base_label.custom_minimum_size.x = 22.0 if compact else 38.0
		_res_label = _base_label
		return
	var pot: bool = _count.has("base") and not _pot_mode().is_empty()
	var base_tone: Color = DeepUi.ORE if pot else _kind_tone
	_base_box = _box(_row, base_tone)
	var base_row := DeepUi.hbox(_base_box, 4)
	DeepUi.icon(base_row, "coins" if pot else str(look[0]), 16.0 if compact else 26.0, base_tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_base_label = _number(base_row, "0" if not _count.get("coef_dice", []).is_empty() else "–", big, base_tone.lightened(0.25))
	_base_label.custom_minimum_size.x = 22.0 if compact else 36.0
	if not _count.has("res") and not bool(_count.get("half", false)):
		return
	var sign := DeepUi.label(_row, "×", 18 if compact else 26, DeepUi.PAPER)
	sign.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
	sign.add_theme_constant_override("outline_size", 5)
	sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _count.has("res"):
		## Resonance gets a box framed in every color: the multiplier no stone carries.
		_mult_box = _rainbow_box(_row)
		_res_box = _mult_box
		var mult_row := DeepUi.hbox(_mult_box, 4)
		DeepUi.icon(mult_row, "resonance", 14.0 if compact else 24.0, DeepUi.PAPER, "", true).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_mult_label = _number(mult_row, "0", big, DeepUi.PAPER)
		_mult_label.custom_minimum_size.x = 18.0 if compact else 32.0
		_res_label = _mult_label
	else:
		## A Bust: half of what was on the table.
		_mult_box = _box(_row, DeepUi.BAD)
		_mult_label = _number(_mult_box, "½", big, DeepUi.BAD.lightened(0.2))
		_mult_label.custom_minimum_size.x = 18.0 if compact else 30.0
		_mult_box.modulate = Color(1, 1, 1, 0.4)

static func _bright(tone: Color) -> Color:
	## A stone's tint made light enough to read as type over a dark room: a black opal's name
	## is written pale, with the opal's play of color in it.
	var light: Color = tone.lightened(0.5)
	return light if light.get_luminance() >= 0.55 else light.lerp(Color("e9e2ff"), 0.75)

static func tier_line(count: Dictionary) -> String:
	## What earned a tier, in a few words under its name: "three of a kind", "2 crowns", and the
	## Changing Face's run when it multiplied the figure. A count with no trigger (a passive)
	## brings its own line.
	var words: String = _tier_words(count)
	var change: int = int(count.get("change", 0))
	if change > 1:
		words = ("%s · " % words if not words.is_empty() else "") + "Changing Face ×%d" % change
	return words

static func _tier_words(count: Dictionary) -> String:
	var trigger: Dictionary = count.get("trigger", {})
	if trigger.is_empty():
		return str(count.get("line", ""))
	var need: int = int(trigger.get("need", 0))
	var numbers: Array = ["no", "one", "two", "three", "four", "five", "six"]
	var said: String = str(numbers[need]) if need >= 0 and need < numbers.size() else str(need)
	match str(trigger.get("kind", "")):
		"pair": return "a pair"
		"triple": return "three of a kind"
		"quad": return "four of a kind"
		"quint": return "five of a kind"
		"straight": return "a straight of %s" % said
		"distinct_dominant": return "one long knife"
		"distinct": return "all five different" if need >= 5 else "%s different" % said
		"low_count": return "all five low" if need >= 5 else "%s low dice" % said
		"value": return "five ones"
		"odd": return "all odd"
		"even": return "all even"
		"skip_straight": return "one parity, all different"
		"crowns":
			## An Ante pays on every crown showing, so it says how many there were.
			var crowns: int = count.get("coef_dice", []).size()
			if crowns > 0:
				return "%s %s" % [str(numbers[crowns]) if crowns < numbers.size() else str(crowns), "crown" if crowns == 1 else "crowns"]
			return "%s crowns" % said
		"crowns_at_most": return "no crown"
	return ""

func _rainbow_box(parent: Control) -> PanelContainer:
	## A box framed in every color, the frame turning slowly: Resonance's own.
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", DeepUi.flat(Color(0.05, 0.03, 0.09, 0.94), Color(0, 0, 0, 0), 6, 5 if compact else 9, 0))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	box.draw.connect(_draw_rainbow.bind(box))
	_rainbows.append(box)
	return box

func _draw_rainbow(box: Control) -> void:
	## Round the box's edge, the wheel laid along it and turning; a soft wide pass under a
	## sharp one, so it glows.
	var inset: float = 1.5
	var rect := Rect2(Vector2.ONE * inset, box.size - Vector2.ONE * inset * 2.0)
	if rect.size.x <= 4.0 or rect.size.y <= 4.0:
		return
	var radius: float = minf(6.0, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners: Array = [[rect.position + Vector2(radius, radius), PI], [Vector2(rect.end.x - radius, rect.position.y + radius), PI * 1.5],
		[rect.end - Vector2(radius, radius), 0.0], [Vector2(rect.position.x + radius, rect.end.y - radius), PI * 0.5]]
	for corner in corners:
		for i in range(7):
			var angle: float = float(corner[1]) + PI * 0.5 * float(i) / 6.0
			points.append((corner[0] as Vector2) + Vector2(cos(angle), sin(angle)) * radius)
	points.append(points[0])
	var colors := PackedColorArray()
	var soft := PackedColorArray()
	for i in range(points.size()):
		var hue: float = fmod(_hue + float(i) / float(points.size() - 1), 1.0)
		var tone := Color.from_hsv(hue, 0.62, 1.0)
		colors.append(tone)
		soft.append(Color(tone, 0.28))
	box.draw_polyline_colors(points, soft, 6.0 if not compact else 4.0, true)
	box.draw_polyline_colors(points, colors, 2.2 if not compact else 1.6, true)

func _call_out() -> void:
	## The tier's name slams in from large and settles, ringing, with a spray of its color.
	if _callout == null:
		return
	_column.modulate.a = 0.0
	_column.create_tween().tween_property(_column, "modulate:a", 1.0, 0.06)
	var call: Control = _callout
	var tween := call.create_tween()
	tween.tween_method(func(t: float) -> void:
		call.pivot_offset = call.size * 0.5
		call.scale = Vector2.ONE * lerpf(2.1, 1.0, t), 0.0, 1.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		DeepUi.spring(call, 0.12, 3.0, 0.4)
		_sparks(_centre(call), color.lightened(0.3), 10 if compact else 30, 140.0 if compact else 240.0))
	var at: Vector2 = _centre(_anchor())
	DeepAudio.play_at(at, "tally_fuse", {"pitch": (chain.pitch(_step, 0) if chain != null else 1.0) * 0.75, "vary": 0.0, "gap": 0.0, "volume": 0.7 * volume})
	DeepAudio.play_at(at, "resonance", {"pitch": 0.95 + 0.06 * float(mini(_step, 6)), "vary": 0.0, "gap": 0.0, "volume": 0.6 * volume})
	_rumble(0.35, 0.45, 0.1)

func _fade() -> void:
	## A tier with no figure: its name has been read, and goes.
	set_process(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 24.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)

func _crown(id: String) -> void:
	## A crown showing: it hops in the tray and sends one more to the count.
	var found: Variant = die_anchor.call(id) if die_anchor.is_valid() else null
	var die: Control = found as Control if found is Control and is_instance_valid(found) else null
	var from: Vector2 = _centre(die) if die != null else _centre(_anchor())
	if die != null:
		if die.has_method("pop"):
			die.call("pop", 1.0, DeepUi.ACCENT_HI)
		else:
			DeepUi.spring(die, 0.3, 10.0, 0.4)
		from.y -= die.size.y * 0.4
	_voice(tick, from, 0.5 + 0.04 * float(_step - start_step))
	_rumble(0.16, 0.0, 0.03)
	_step += 1
	_fly(from, _centre(_base_box), "+1", "", DeepUi.ACCENT_HI, DeepBattle.TALLY_FLIGHT * _pace, func() -> void: _set_base(_base + 1), "crown")

func _reveal_tier_base(seconds: float) -> void:
	## The number Resonance will multiply: the tier's own, flown in from where it comes from
	## (the rerolls left, off their button; the pot, off the table), or simply set.
	var base: int = int(_count.get("base", _count.get("coef", 1)))
	var from_found: Variant = null
	var glyph: String = ""
	var note: String = ""
	var tint: Color = _kind_tone
	if not _pot_mode().is_empty() and _count.has("base"):
		from_found = pot_anchor.call() if pot_anchor.is_valid() else null
		glyph = "coins"
		note = "the pot"
		tint = DeepUi.ORE
	elif str(_count.get("coef_what", "")) == "rerolls":
		from_found = coef_anchor.call() if coef_anchor.is_valid() else null
		glyph = "reroll"
		note = "rerolls left"
		tint = DeepUi.INFO
	var source: Control = from_found as Control if from_found is Control and is_instance_valid(from_found) and (from_found as Control).is_inside_tree() else null
	if source == null:
		_set_base(base)
		_voice(tick, _centre(_base_box), 0.55)
		_step += 1
		return
	DeepUi.spring(source, 0.25, 6.0, 0.4)
	var step: int = _step
	_step += 1
	_fly(_centre(source), _centre(_base_box), str(base), note, tint, clampf(seconds * 0.7, 0.05, 0.24), func() -> void:
		_set_base(base)
		_voice(tick, _centre(_base_box), 0.6, step), glyph)

func _flow() -> void:
	## Resonance streams out of the rail's counter as light, every color of it, and the box
	## counts it in as it lands: a rising run of ticks, the chain being spent.
	var found: Variant = flow_from.call() if flow_from.is_valid() else null
	var source: Control = found as Control if found is Control and is_instance_valid(found) and (found as Control).is_inside_tree() else null
	var to: Vector2 = _centre(_res_box)
	var from: Vector2 = _centre(source) if source != null else _centre(_anchor())
	var total: int = int(_count.get("res", 0))
	if source != null:
		DeepUi.spring(source, 0.35, 6.0, 0.5)
	if from.is_finite():
		_rainbow_sparks(from, 18 if not compact else 6, 150.0)
	DeepAudio.play_at(from if from.is_finite() else to, "resonance", {"pitch": 1.1, "vary": 0.0, "gap": 0.0, "volume": 0.7 * volume})
	var motes: int = clampi(total, 3, 14) if not compact else clampi(total, 2, 6)
	var window: float = DeepBattle.BIRTH_FLOW * _pace * 0.5
	var flight: float = maxf(0.08, DeepBattle.BIRTH_FLOW * _pace * 0.42)
	var first: int = _step
	for i in range(motes):
		var reached: int = int(round(float(total) * float(i + 1) / float(motes)))
		var hue: float = float(i) / float(maxi(1, motes))
		_mote(from, to, DeepUi.rainbow_at(hue, 0.7), window * float(i) / float(maxi(1, motes - 1)), flight, _flowed.bind(reached, i, motes, first))

func _flowed(value: int, index: int, motes: int, first: int) -> void:
	_res_label.text = str(value)
	DeepUi.spring(_res_box, 0.16 + 0.12 * float(index + 1) / float(motes), 5.0, 0.3)
	if index % 2 == 0 or index == motes - 1:
		_voice(tick, _centre(_res_box), 0.45 + 0.25 * float(index) / float(motes), first + index * 9 / maxi(1, motes - 1))
	if index == motes - 1:
		## In: the whole of it, ringing.
		_rainbow_sparks(_centre(_res_box), 26 if not compact else 8, 170.0)
		_voice("tally_mult", _centre(_res_box), 0.8, first + 4)
		_rumble(0.25, 0.35, 0.07)
		DeepUi.spring(_res_box, 0.38, 8.0, 0.45)
		_step = first + 5

func _mote(from: Vector2, to: Vector2, tint: Color, delay: float, seconds: float, landed: Callable) -> void:
	## One spark of Resonance on its way: a soft light trailing its color, bowing out and in.
	if not from.is_finite() or not to.is_finite():
		get_tree().create_timer(delay + seconds).timeout.connect(func() -> void:
			if is_instance_valid(self):
				landed.call())
		return
	var mote := Control.new()
	mote.top_level = true
	mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mote.z_index = 6
	add_child(mote)
	var trail := CPUParticles2D.new()
	trail.local_coords = false
	trail.amount = 10
	trail.lifetime = 0.22
	trail.texture = DeepUi.dot_texture()
	trail.spread = 180.0
	trail.initial_velocity_min = 4.0
	trail.initial_velocity_max = 18.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 0.12
	trail.scale_amount_max = 0.3
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.95))
	fade.set_color(1, Color(tint, 0.0))
	trail.color_ramp = fade
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail.material = add
	mote.add_child(trail)
	var glow := TextureRect.new()
	glow.texture = DeepUi.glow_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(36, 36) if not compact else Vector2(18, 18)
	glow.position = - glow.size * 0.5
	glow.modulate = tint
	glow.material = add
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mote.add_child(glow)
	mote.global_position = from
	mote.visible = false
	trail.emitting = false
	var bend: Vector2 = (from + to) * 0.5 + Vector2(randf_range(-110.0, 110.0), randf_range(-120.0, -30.0))
	var tween := mote.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		mote.visible = true
		trail.emitting = true)
	tween.tween_method(func(t: float) -> void:
		var eased: float = t * t * (3.0 - 2.0 * t)
		mote.global_position = from.lerp(bend, eased).lerp(bend.lerp(to, eased), eased)
		mote.scale = Vector2.ONE * lerpf(1.25, 0.7, t), 0.0, 1.0, seconds)
	tween.tween_callback(func() -> void:
		glow.visible = false
		trail.emitting = false
		landed.call())
	tween.tween_interval(trail.lifetime + 0.05)
	tween.tween_callback(mote.queue_free)

func _rainbow_sparks(at: Vector2, amount: int, speed: float, behind: bool = false) -> void:
	## A spray in every color: three bursts off the wheel; `behind` the plate, so a number
	## being sprayed over and over stays readable.
	var parent: Control = get_parent() as Control
	if parent == null or not at.is_finite():
		return
	for i in range(3):
		var count: int = maxi(3, amount / 3)
		DeepUi.burst(parent, at - parent.get_global_rect().position, DeepUi.rainbow_at(float(i) / 2.0, 0.75), maxi(2, count / 3) if ScreenFx.calm else count,
			speed, 0.4, 4.0, z_index - 2 if behind else 60)

func _bank_in(seconds: float) -> void:
	## The bank matches the pot (a Raise) or goes in whole (All In): its coins leave the purse
	## for the count, and the pot reads what is riding.
	var pot: Dictionary = _count.get("pot", {})
	var moved: int = int(pot.get("moved", 0))
	var found: Variant = bank_anchor.call() if bank_anchor.is_valid() else null
	var source: Control = found as Control if found is Control and is_instance_valid(found) and (found as Control).is_inside_tree() else null
	var from: Vector2 = _centre(source) if source != null else _centre(_anchor())
	if on_bank.is_valid() and moved > 0:
		on_bank.call(-moved)
	if source != null:
		DeepUi.spring(source, 0.3, 8.0, 0.4)
	var step: int = _step
	_step += 1
	var note: String = "all in" if _pot_mode() == "all" else "matched"
	_fly(from, _centre(_base_box), "+%d" % moved, note, DeepUi.ORE, clampf(seconds * 0.8, 0.06, 0.3), func() -> void:
		_set_base(_base + moved)
		_voice("tally_mult", _centre(_base_box), 0.75, step)
		DeepAudio.play_at(_centre(_base_box), "ore", {"volume": 0.6 * volume, "gap": 0.0})
		_rumble(0.22, 0.32, 0.06)
		if on_pot.is_valid():
			on_pot.call(int(pot.get("total", 0))), "coins")

func _halve() -> void:
	## A Bust: the table takes the pot, and half of it comes out of him.
	_mult_box.modulate = Color.WHITE
	DeepUi.spring(_mult_box, 0.3, 8.0, 0.42)
	_sparks(_centre(_mult_box), DeepUi.BAD, 14, 130.0)
	_voice("tally_mult", _centre(_mult_box), 0.7, maxi(0, _step - 4))
	_step += 1

func _tier_fuse(whole: bool) -> void:
	## The boxes become one figure: what lands, before what every blow carries on top (or,
	## with the counts off, all of it).
	var added: int = 0
	if not whole:
		for entry in _count.get("adds", []):
			added += int(entry.get("by", 0))
	_total = int(_count.get("amount", 0)) - added
	if _row != null:
		var centre: Vector2 = _centre(_row)
		_streak(_centre(_base_box), centre, _kind_tone)
		if _mult_box != null:
			_streak(_centre(_mult_box), centre, DeepUi.rainbow_at(0.5, 0.7) if _count.has("res") else DeepUi.BAD)
		_row.visible = false
	var tone: Color = Color("ffcf5a") if blaze else _kind_tone
	_total_box = _box(_column, tone)
	_total_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var line := DeepUi.hbox(_total_box, 6)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	var look: Array = kind_look(str(_count.get("kind", "")))
	var size_now: int = (22 if compact else 38) + mini(12, _total / 8)
	DeepUi.icon(line, str(look[0]), float(size_now) * 0.8, tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_total_label = _number(line, str(_total), size_now, tone.lightened(0.3))
	var repeat: int = int(_count.get("repeat", 1))
	if repeat > 1 and (whole or str(_count.get("repeat_die", "")).is_empty()):
		_number(line, "×%d" % repeat, maxi(14, size_now - 10), DeepUi.PAPER)
	## What else lands with it: Full Motley's guard beside its blow.
	for other in _count.get("also", []):
		var other_look: Array = kind_look(str(other.get("kind", "")))
		DeepUi.icon(line, str(other_look[0]), float(size_now) * 0.6, other_look[1]).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_number(line, str(int(other.get("amount", 0))), maxi(14, size_now - 8), (other_look[1] as Color).lightened(0.3))
	if blaze:
		_ignite(_total_box)
	DeepUi.spring(_total_box, 0.42 if blaze else 0.36, 9.0 if blaze else 7.0, 0.55 if blaze else 0.5)
	var at: Vector2 = _centre(_row) if _row != null else _centre(_column)
	_sparks(at, tone, 34 if blaze else 22, 220.0 if blaze else 170.0)
	_voice("tally_fuse", at, 0.85, _step)
	if blaze:
		DeepAudio.play_at(at, "tally_blaze", {"volume": 0.8 * volume, "gap": 0.0})
	_rumble(0.45 if blaze else 0.35, 0.8 if blaze else 0.55, 0.16 if blaze else 0.09)
	_step += 1
	if on_fuse.is_valid():
		on_fuse.call(_total, blaze)
	## An Ante's stake leaves the purse for the table as its figure is made; a Bust's pot is
	## swept off the table.
	var pot: Dictionary = _count.get("pot", {})
	if _pot_mode() == "ante" and int(pot.get("moved", 0)) > 0:
		stake_coins(int(pot.moved), int(pot.get("total", 0)))
	elif _pot_mode() == "lose":
		var found: Variant = pot_anchor.call() if pot_anchor.is_valid() else null
		if found is Control and is_instance_valid(found):
			_sparks(_centre(found as Control), DeepUi.ORE, 30, 200.0)
			DeepUi.shake(found as Control, 10.0, 0.35)
		DeepAudio.play_at(at, "salvage_lose", {"volume": 0.6 * volume, "gap": 0.0})
		if on_pot.is_valid():
			on_pot.call(0)

func stake_coins(moved: int, total: int) -> void:
	## Pyrite out of the purse and onto the table: the purse reads it gone as the coins leave,
	## the pot reads it riding as they land.
	var bank_found: Variant = bank_anchor.call() if bank_anchor.is_valid() else null
	var pot_found: Variant = pot_anchor.call() if pot_anchor.is_valid() else null
	var from: Vector2 = _centre(bank_found as Control) if bank_found is Control and is_instance_valid(bank_found) else Vector2.INF
	var to: Vector2 = _centre(pot_found as Control) if pot_found is Control and is_instance_valid(pot_found) else Vector2.INF
	if on_bank.is_valid():
		on_bank.call(-moved)
	var landed := func() -> void:
		if on_pot.is_valid():
			on_pot.call(total)
	var parent: Control = get_parent() as Control
	if parent == null or not from.is_finite() or not to.is_finite():
		landed.call()
		return
	coins(parent, from, to, moved, 0.45, landed, volume)

static func coins(parent: Control, from: Vector2, to: Vector2, amount: int, seconds: float, landed: Callable, loudness: float = 1.0) -> void:
	## Pyrite moving: a run of coins from one place to another, a clink as each lands, and
	## `landed` once the last is in. On the screen itself, so it outlives whoever threw it.
	if DeepUi.headless() or parent == null or not parent.is_inside_tree() or not from.is_finite() or not to.is_finite():
		landed.call()
		return
	var origin: Vector2 = parent.get_global_rect().position
	var count: int = clampi(3 + amount / 4, 3, 12)
	for i in range(count):
		var coin := DeepUi.icon(parent, "coin", randf_range(14.0, 20.0), DeepUi.ORE.lightened(randf_range(0.0, 0.3)))
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.z_index = 55
		var half: Vector2 = coin.custom_minimum_size * 0.5
		coin.pivot_offset = half
		var start: Vector2 = from - origin + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
		var end: Vector2 = to - origin + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
		var bend: Vector2 = (start + end) * 0.5 + Vector2(randf_range(-60.0, 60.0), -40.0 - absf(end.x - start.x) * 0.15)
		coin.position = start - half
		coin.visible = false
		var last: bool = i == count - 1
		var tween := coin.create_tween()
		tween.tween_interval(seconds * 0.45 * float(i) / float(count))
		tween.tween_callback(func() -> void: coin.visible = true)
		tween.tween_method(func(t: float) -> void:
			var eased: float = t * t * (3.0 - 2.0 * t)
			coin.position = start.lerp(bend, eased).lerp(bend.lerp(end, eased), eased) - half
			coin.rotation = t * 6.0, 0.0, 1.0, seconds * 0.55)
		tween.tween_callback(func() -> void:
			if i % 3 == 0 or last:
				DeepAudio.play_at(to, "ore", {"volume": 0.35 * loudness, "pitch": 1.0 + 0.04 * float(i), "vary": 0.0, "gap": 0.0})
			if last:
				DeepUi.burst(parent, end, DeepUi.ORE, 14, 120.0, 0.45, 4.0)
				landed.call()
			coin.queue_free())

func _repeat_in(seconds: float) -> void:
	## The die that says how many times: it hops, and its number flies in as the count of blows.
	var id: String = str(_count.get("repeat_die", ""))
	var repeat: int = int(_count.get("repeat", 1))
	var found: Variant = die_anchor.call(id) if die_anchor.is_valid() else null
	var die: Control = found as Control if found is Control and is_instance_valid(found) else null
	var from: Vector2 = _centre(die) if die != null else _centre(_anchor())
	if die != null:
		if die.has_method("pop"):
			die.call("pop", 1.3, color.lightened(0.3))
		from.y -= die.size.y * 0.4
	var step: int = _step
	_step += 1
	_fly(from, _centre(_total_box), "×%d" % repeat, "times", DeepUi.PAPER, clampf(seconds * 0.7, 0.05, 0.24), func() -> void:
		if _total_label == null:
			return
		var over := _number(_total_label.get_parent(), "×%d" % repeat, maxi(14, int(_total_label.get_theme_font_size("font_size")) - 8), DeepUi.PAPER)
		over.tooltip_text = "Lands this many times"
		DeepUi.spring(_total_box, 0.3, 7.0, 0.4)
		_voice("tally_mult", _centre(_total_box), 0.8, step)
		_rumble(0.3, 0.45, 0.08), "die")

func toss(from: Vector2, to: Vector2, text: String, note: String, tint: Color, seconds: float, landed: Callable, glyph: String = "") -> void:
	## One number thrown from one place to another on its own (a Study's reroll onto the
	## button), the plate gone once it has landed.
	_fly(from, to, text, note, tint, seconds, func() -> void:
		landed.call()
		get_tree().create_timer(0.35).timeout.connect(queue_free), glyph)

func call_only(title: String, line: String) -> void:
	## A name called out over its anchor and nothing counted under it (House Money), gone
	## once it has been read.
	_count = {"name": title, "line": line}
	_numbered = false
	_build_tier()
	_place()
	_call_out()
	create_tween().tween_callback(_fade).set_delay(0.9)

# --- a swell ------------------------------------------------------------------------------------

func open_swell(title: String, kind: String) -> void:
	## A figure that grows for as long as a gem keeps landing blows: its name over a box framed
	## in every color, since it is Resonance that each blow pays. Shown at the first `swell`.
	_tally = {"kind": kind}
	_kind_tone = kind_look(kind)[1]
	_pace = 1.0
	_step = start_step
	_column = DeepUi.vbox(self, 0)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := DeepUi.title(_column, title, 16 if compact else 30, color.lightened(0.45), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_color_override("font_outline_color", Color(DeepUi.INK, 0.95))
	name_label.add_theme_constant_override("outline_size", 5 if compact else 9)
	_callout = name_label
	_total_box = _rainbow_box(_column)
	_total_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var line := DeepUi.hbox(_total_box, 5)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.icon(line, str(kind_look(kind)[0]), 16.0 if compact else 26.0, _kind_tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_total_label = _number(line, "0", 18 if compact else 34, DeepUi.PAPER)
	_total_label.custom_minimum_size.x = 20.0 if compact else 40.0
	_res_label = _total_label
	_column.modulate.a = 0.0

func swell(by: int) -> void:
	## One more blow landed: the figure climbs by what it paid, a step up the scale, bigger and
	## shaking harder each time, and from the third it burns.
	_swells += 1
	_total += by
	_total_label.text = str(_total)
	var grown: int = (18 if compact else 34) + mini(8 if compact else 26, 3 * (_swells - 1))
	_total_label.add_theme_font_size_override("font_size", grown)
	if _swells == 1:
		_place()
		_appear()
		if _callout != null:
			DeepUi.spring(_callout, 0.3, 4.0, 0.45)
	var push: float = minf(0.45, 0.2 + 0.03 * float(_swells))
	DeepUi.spring(_total_box, push, 6.0 + float(mini(_swells, 8)), 0.42)
	DeepUi.shake(self, 2.0 + 0.6 * float(mini(_swells, 10)), 0.22)
	_rainbow_sparks(_centre(_total_box), (10 if compact else 18) + 3 * mini(_swells, 10), 120.0 + 12.0 * float(mini(_swells, 10)), true)
	_voice(tick, _centre(_total_box), minf(1.0, 0.5 + 0.06 * float(_swells)), start_step + _swells - 1)
	_rumble(minf(0.5, 0.15 + 0.04 * float(_swells)), minf(0.6, 0.05 * float(_swells)), 0.05)
	if _swells >= 3 and not _burning and not compact:
		_burning = true
		_ignite(_total_box)

func close_swell() -> void:
	## The gem has had its say: what it all came to flies to where it lands.
	if _swells <= 0:
		queue_free()
		return
	_launch()
