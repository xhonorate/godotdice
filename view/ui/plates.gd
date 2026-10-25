extends RefCounted
## The one plate form every instant tooltip in a run is built in (docs/UI_REDO.md): a title
## line, small capitals for a section, keyword-colored rules text, and for a gem the strip
## that lights the dice in the hand that meet it. Built fresh on every hover (see tips.gd),
## so what it says is always what the fight says now.

const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Tips = preload("res://view/ui/tips.gd")

const WIDTH: float = 330.0
const FOOTER: String = "Right-click · everything"

static func head(box: Control, title: String, small: String, tone: Color = DeepUi.PAPER) -> HBoxContainer:
	## The title line: the name in bold, and after it what kind of thing it is, in small capitals.
	var row := DeepUi.hbox(box, 8)
	var name_label := DeepUi.label(row, title, 17, tone)
	name_label.add_theme_font_override("font", DeepUi.bold_font())
	if not small.is_empty():
		var kind := DeepUi.label(row, small.to_upper(), 11, DeepUi.MUTED)
		kind.add_theme_font_override("font", DeepUi.bold_font())
		kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row

static func section(box: Control, words: String) -> Label:
	var l := DeepUi.heading(box, words, 10, Color("ffc247"))
	return l

static func footer(box: Control, words: String = FOOTER) -> void:
	DeepUi.label(box, words, 10, DeepUi.DIM)

static func plate(width: float = WIDTH) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = width
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	return box

# --- gems --------------------------------------------------------------------------------------

static func gem_small(stone: Dictionary, context: Dictionary = {}) -> String:
	## "RED · 6 ct · GOOD": its color, its weight as the rail counts it, and its cut as judged.
	var eff: Dictionary = DeepStone.effective(stone, context)
	var parts: Array = [str(DeepContent.color(DeepStone.color(stone)).get("name", DeepStone.color(stone)))]
	parts.append("%d ct" % int(eff.carat))
	parts.append(DeepContent.cut_name(mini(int(eff.cut_step), DeepPatterns.STEPS - 1)))
	if DeepStone.is_slotless(stone):
		parts.append("Void")
	return " · ".join(parts)

static func gem(stone: Dictionary, context: Dictionary, hand: Array, entry: Dictionary, dice: Array, opts: Dictionary = {}) -> Control:
	## A gem on the rail: what it is, when it fires at its own cut, what it does, and whether
	## this hand fires it. `entry` is the forecast's socket entry ({} when none applies);
	## `hand` the rolls and `dice` the dice they came from. `opts.riders` lays out the Void
	## gems riding this socket in firing order; `opts.rider_of` says this is one of them.
	var box := plate()
	var skill: Dictionary = DeepStone.skill_of(stone)
	var tone: Color = DeepUi.color(DeepStone.color(stone))
	head(box, str(skill.get("name", stone.get("skill", "Stone"))), gem_small(stone, context), tone.lightened(0.3))
	var eff: Dictionary = DeepStone.effective(stone, context)
	if DeepStone.is_birthstone(stone):
		DeepUi.label(box, "%s, your Birthstone" % str(stone.get("name", "")), 12, DeepUi.MUTED)
	## When it fires: the pictograph and the words for the rung this stone stands on. The
	## other rungs are the inspector's.
	var described: Dictionary = entry.get("trigger", DeepPatterns.describe(skill.get("trigger", {"kind": "always"}), int(eff.cut_step)))
	var fires := DeepUi.hbox(box, 8)
	DiceIcons.build(fires, described, 16, DeepUi.PAPER)
	var said := DeepUi.vbox(fires, 0)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.effect_text(said, str(described.get("words", "")), 12, DeepUi.PAPER)
	DeepUi.rule(box, DeepUi.LEDGER_LINE).custom_minimum_size = Vector2(0, 2)
	DeepUi.effect_text(box, DeepStone.text(stone, context), 13, DeepUi.PAPER)
	if bool(eff.flawless) and skill.get("flawless", null) is Dictionary:
		var flawless := DeepUi.hbox(box, 6)
		DeepUi.icon(flawless, "star", 13, DeepUi.tier_color("PEERLESS"))
		var flawless_said := DeepUi.vbox(flawless, 0)
		flawless_said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.effect_text(flawless_said, "Flawless: " + DeepStone.flawless_text(stone, context), 12, DeepUi.tier_color("PEERLESS"))
	_weight_line(box, stone, context, eff)
	for line in DeepStone.proc_lines(stone, context):
		DeepUi.stat(box, "carat", str(line.text), DeepUi.GOOD if bool(line.sure) else DeepUi.MUTED, 11)
	if opts.has("riders"):
		_rider_row(box, stone, opts.riders, int(opts.get("socket", 0)), bool(opts.get("rider_of", false)))
	if not str(opts.get("note", "")).is_empty():
		DeepUi.stat(box, "cross_out", str(opts.note), DeepUi.BAD, 12)
	if not hand.is_empty() and not entry.is_empty():
		_this_hand(box, hand, dice, entry)
	return box

static func _weight_line(box: Control, stone: Dictionary, context: Dictionary, eff: Dictionary) -> void:
	## What the stone's weight multiplies its numbers by, as one underlined figure; rest the
	## pointer on it and the working opens beside the plate (tips.gd).
	if not DeepStone.magnitude_matters(stone):
		return
	var magnitude: float = float(eff.magnitude)
	var rtl := RichTextLabel.new()
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_STOP
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.set_text_size(rtl, 12)
	rtl.push_color(DeepUi.MUTED)
	rtl.add_text("Every number above is ")
	rtl.push_color(Color("ffd77a"))
	rtl.push_font(DeepUi.bold_font())
	rtl.push_meta("weight", RichTextLabel.META_UNDERLINE_ALWAYS)
	rtl.add_text("×%s" % _times(magnitude))
	rtl.pop()
	rtl.pop()
	rtl.pop()
	rtl.add_text(" for its weight.")
	rtl.pop_all()
	box.add_child(rtl)
	var parts: Dictionary = eff.get("parts", {})
	rtl.meta_hover_started.connect(func(_meta: Variant) -> void:
		Tips.show_sub(rtl, func() -> Control: return working(stone, parts, magnitude)))
	rtl.meta_hover_ended.connect(func(_meta: Variant) -> void: Tips.hide_sub())

static func _times(value: float) -> String:
	var text: String = "%.2f" % value
	return text.rstrip("0").rstrip(".") if text.contains(".") else text

static func working(stone: Dictionary, parts: Dictionary, magnitude: float) -> Control:
	## The working behind a multiplied number: each factor and where it comes from, and the
	## total on a gold plate.
	var box := plate(230.0)
	box.add_theme_constant_override("separation", 3)
	var rows: Array = []
	var weight: float = float(parts.get("weight", stone.get("carat", 1)))
	rows.append(["Carat", "%s ct" % _times(weight), "×%s" % _times(float(parts.get("carat", 1.0)))])
	if not is_equal_approx(float(parts.get("clarity", 1.0)), 1.0):
		rows.append(["Clarity", DeepContent.clarity_name(int(stone.get("clarity", 0))), "×%s" % _times(float(parts.get("clarity", 1.0)))])
	if not is_equal_approx(float(parts.get("inclusions", 1.0)), 1.0):
		rows.append(["Inclusions", "", "×%s" % _times(float(parts.get("inclusions", 1.0)))])
	if not is_equal_approx(float(parts.get("amplify", 1.0)), 1.0):
		rows.append(["Amplified", "this gem only", "×%s" % _times(float(parts.get("amplify", 1.0)))])
	for row in rows:
		var line := DeepUi.hbox(box, 10)
		var words := DeepUi.vbox(line, 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(words, str(row[0]), 13, DeepUi.PAPER)
		if not str(row[1]).is_empty():
			DeepUi.label(words, str(row[1]), 11, DeepUi.MUTED)
		var value := DeepUi.label(line, str(row[2]), 15, Color.WHITE)
		value.add_theme_font_override("font", DeepUi.bold_font())
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.rule(box, DeepUi.LEDGER_LINE)
	var total := DeepUi.hbox(box, 10)
	var total_words := DeepUi.label(total, "Multiplier", 13, Color("ffd77a"))
	total_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gold := PanelContainer.new()
	gold.add_theme_stylebox_override("panel", DeepUi.capsule(gold, Color("ffc247"), Color("ffc247"), 1, 12, 1))
	gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	total.add_child(gold)
	var figure := DeepUi.label(gold, "×%s" % _times(magnitude), 15, Color("1a1406"))
	figure.add_theme_font_override("font", DeepUi.bold_font())
	return box

static func _rider_row(box: Control, stone: Dictionary, riders: Array, socket: int, rider_of: bool) -> void:
	## The Void gems riding a socket, in the order they fire: the socket's own gem first, then
	## each rider, then an empty ring where the next would go.
	section(box, "Rides socket %d" % (socket + 1) if rider_of else "Riders · fire after it in this order")
	var row := DeepUi.hbox(box, 6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var first: Dictionary = riders[0] if rider_of and not riders.is_empty() else stone
	var line: Array = riders.slice(1) if rider_of else riders
	_rider_mark(row, first, not rider_of)
	for rider in line:
		DeepUi.label(row, "›", 12, DeepUi.DIM)
		_rider_mark(row, rider, rider_of and str(rider.get("id", "")) == str(stone.get("id", "")))
	DeepUi.label(row, "›", 12, DeepUi.DIM)
	var empty := Control.new()
	empty.custom_minimum_size = Vector2(26, 26)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.draw.connect(func() -> void:
		for arc in range(6):
			var angle: float = TAU * float(arc) / 6.0
			empty.draw_arc(Vector2(13, 13), 11.0, angle, angle + TAU / 9.0, 8, Color(DeepUi.INFO, 0.5), 1.5, true))
	row.add_child(empty)

static func _rider_mark(row: Control, rider: Dictionary, here: bool) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(26, 26)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(holder)
	if here:
		var ring := Control.new()
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.draw.connect(func() -> void: ring.draw_arc(Vector2(13, 13), 12.5, 0.0, TAU, 32, Color("ffc247"), 2.0, true))
		holder.add_child(ring)
	var thumb := Thumbs.GemThumb.new(rider, 22)
	thumb.position = Vector2(2, 2)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.live_on_hover = false
	holder.add_child(thumb)

static func outcome(entry: Dictionary) -> Array:
	## What a firing gem lands, as [text, color] pairs by kind, biggest first: 12 damage, 6
	## block, 3 healing, 2 poison, 5 pyrite, Resonance.
	var sums: Dictionary = {}
	for effect in entry.get("effects", []):
		if not effect is Dictionary:
			continue
		var kind: String = str(effect.get("kind", ""))
		var amount: int = int(effect.get("raw", effect.get("amount", 0))) if kind == "damage" else int(effect.get("amount", 0))
		if kind in ["appraise", "invert_previous"]:
			for hit in effect.get("hits", []):
				sums["damage"] = int(sums.get("damage", 0)) + int(hit.get("raw", hit.get("amount", 0)))
			continue
		if kind in ["damage", "block", "heal", "poison", "gold", "amplify", "reroll", "phantom", "stun"]:
			sums[kind] = int(sums.get(kind, 0)) + amount
	var out: Array = []
	var looks: Dictionary = {"damage": ["%s damage", DeepUi.EFFECT_KEYWORDS.damage.color], "block": ["+%s block", DeepUi.EFFECT_KEYWORDS.block.color],
		"heal": ["+%s healing", DeepUi.EFFECT_KEYWORDS.heal.color], "poison": ["%s poison", DeepUi.EFFECT_KEYWORDS.poison.color],
		"gold": ["+%s pyrite", DeepUi.ORE], "reroll": ["+%s reroll", DeepUi.INFO], "phantom": ["%s phantom", DeepUi.INFO], "stun": ["%s stun", Color("ffe27a")]}
	for kind in ["damage", "block", "heal", "poison", "gold", "reroll", "phantom", "stun"]:
		if int(sums.get(kind, 0)) > 0:
			out.append([str(looks[kind][0]) % DeepUi.number(int(sums[kind])), looks[kind][1]])
	return out

static func badge(entry: Dictionary) -> Array:
	## The one figure a lit socket wears: [text, color], or ["", _] for a gem whose work has no
	## number (its FIRES tag says enough).
	for effect in entry.get("effects", []):
		if effect is Dictionary and str(effect.get("kind", "")) == "amplify" and float(effect.get("amount", 1.0)) > 1.0:
			return ["×%s" % _times(float(effect.amount)), DeepUi.ACCENT_HI]
	var parts: Array = outcome(entry)
	if parts.is_empty():
		return ["", DeepUi.PAPER]
	var first: Array = parts[0]
	var text: String = str(first[0]).split(" ")[0]
	return [text, first[1]]

static func _this_hand(box: Control, hand: Array, dice: Array, entry: Dictionary) -> void:
	## The strip: the hand's dice as small faces, the ones this gem reads lit, and what lands.
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", DeepUi.flat(Color("1c2232"), Color(0, 0, 0, 0), 5, 6))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(strip)
	var row := DeepUi.hbox(strip, 6)
	var read: Array = entry.get("dice", []).map(func(d: Variant) -> String: return str(d))
	var active: bool = bool(entry.get("active", false))
	var by_id: Dictionary = {}
	for die in dice:
		by_id[str(die.get("id", ""))] = die
	for roll in hand:
		if bool(roll.get("phantom", false)):
			continue
		var id: String = str(roll.get("die_id", ""))
		var lit: bool = active and read.has(id)
		var shape: String = str(by_id.get(id, {}).get("shape", roll.get("shape", "D6")))
		row.add_child(DiceIcons.face(18, int(roll.get("value", 0)), Color.WHITE if lit else DeepUi.LINE_HI, shape, lit,
			DiceIcons.face_text(int(roll.get("value", 0)), str(roll.get("kind", "plain")))))
	var words := DeepUi.vbox(row, 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if active:
		var lands: Array = outcome(entry)
		var rtl := RichTextLabel.new()
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.set_text_size(rtl, 12)
		rtl.push_font(DeepUi.bold_font())
		rtl.push_color(Color("ffd77a"))
		rtl.add_text("Fires" + (" ×%d" % int(entry.get("fires", 1)) if int(entry.get("fires", 1)) > 1 else ""))
		rtl.pop()
		for i in range(lands.size()):
			rtl.push_color(DeepUi.MUTED)
			rtl.add_text(" · ")
			rtl.pop()
			rtl.push_color(Color(lands[i][1]))
			rtl.add_text(str(lands[i][0]))
			rtl.pop()
		rtl.pop_all()
		words.add_child(rtl)
	else:
		var why: String = str(entry.get("reason", ""))
		DeepUi.wrap(words, "Stays dark" + (": " + why if not why.is_empty() else "."), 12, DeepUi.MUTED)

# --- dice --------------------------------------------------------------------------------------

static func die(item: Dictionary, roll: Dictionary = {}, opts: Dictionary = {}) -> Control:
	## A die in the tray: what it is, its faces with the one it landed on lit, and whatever is
	## cut into it. `opts.note` is a line about this turn (locked, lent, a phantom's source).
	var box := plate(300.0)
	var tone: Color = DiceIcons.die_palette(item).body
	head(box, DeepDice.describe(item), "%d faces" % item.get("faces", []).size(), tone.lightened(0.2))
	var faces := HFlowContainer.new()
	faces.add_theme_constant_override("h_separation", 3)
	faces.add_theme_constant_override("v_separation", 3)
	faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(faces)
	var landed: int = int(roll.get("face", -1)) if not roll.is_empty() else -1
	var list: Array = item.get("faces", [])
	for index in range(list.size()):
		var face: Dictionary = list[index]
		var here: bool = index == landed
		faces.add_child(DiceIcons.face(20, int(face.get("value", 0)), Color.WHITE if here else tone, str(item.get("shape", "D6")), here,
			DiceIcons.face_text(int(face.get("value", 0)), str(face.get("kind", "plain")))))
	var material: String = str(item.get("material", ""))
	var pattern: String = str(item.get("pattern", ""))
	var lines: Array = []
	if not material.is_empty():
		lines.append([DeepDice.material_name(material), str(DeepContent.material(material).get("text", ""))])
	if not pattern.is_empty():
		lines.append([DeepDice.pattern_name(pattern), str(DeepContent.pattern(pattern).get("text", ""))])
	for entry in DeepDice.etchings(item):
		lines.append([DeepDice.etching_name(str(entry.kind)), str(DeepContent.etching(str(entry.kind)).get("text", ""))])
	if not lines.is_empty():
		section(box, "Cut into it")
		for line in lines:
			var rtl := DeepUi.effect_text(box, "%s: %s" % [str(line[0]), str(line[1])], 12, DeepUi.PAPER)
			rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ghosts: Array = opts.get("phantoms", [])
	if not ghosts.is_empty():
		section(box, "%s behind it" % DeepUi.plural(ghosts.size(), "phantom"))
		var ghost_row := DeepUi.hbox(box, 6)
		for ghost in ghosts:
			ghost_row.add_child(DiceIcons.face(22, int(ghost.get("value", 0)), DeepUi.INFO, str(item.get("shape", "D6")), true, str(int(ghost.get("value", 0)))))
		var ghost_words := DeepUi.vbox(ghost_row, 0)
		ghost_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ghost_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		DeepUi.wrap(ghost_words, "Copies made by a Refract: each counts for every gem after the one that made it, then fades.", 11, DeepUi.MUTED)
	var note: String = str(opts.get("note", ""))
	if not note.is_empty():
		DeepUi.stat(box, str(opts.get("note_glyph", "spark")), note, Color(opts.get("note_tone", DeepUi.INFO)), 12)
	return box

static func phantom(ghosts: Array, source: Dictionary) -> Control:
	## A Refract's phantoms behind the die they copy: each one, and what it is.
	var box := plate(300.0)
	head(box, "%s behind this die" % DeepUi.plural(ghosts.size(), "phantom"), "copies", DeepUi.INFO)
	var row := DeepUi.hbox(box, 6)
	for ghost in ghosts:
		row.add_child(DiceIcons.face(22, int(ghost.get("value", 0)), DeepUi.INFO, str(source.get("shape", ghost.get("shape", "D6"))), true, str(int(ghost.get("value", 0)))))
	DeepUi.wrap(box, "Copies of your %s, made by a Refract. Each counts for every gem after the one that made it this turn, then fades." % DeepDice.describe(source), 12, DeepUi.MUTED)
	return box

# --- chips and words ---------------------------------------------------------------------------

static func words(title: String, text: String, small: String = "", tone: Color = DeepUi.PAPER) -> Control:
	## A plate for a chip or a button: a title and a sentence.
	var box := plate(280.0)
	head(box, title, small, tone)
	DeepUi.effect_text(box, text, 12, DeepUi.PAPER)
	return box
