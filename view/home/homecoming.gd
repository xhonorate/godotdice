extends RefCounted
## Coming home: back from a run with stones on the tray, the workshop waits until every one of
## them is decided. The tray down the left; the stone being looked at under the loupe in the
## middle, read right there (the rock comes off, the lines are read out one at a time); and,
## once it is known and one of its skill is already kept, that one on the right to weigh it
## against. Keep, sell or turn it in. A stone the purse cannot pay to read is sold rough.
## When the tray is empty, the way into the workshop opens.
##
## The same bench, without the hold on the workshop, is the vault's Unappraised view: stones
## left waiting on the tray (from a Geode or a contract) are decided there.

const StoneCard = preload("res://view/gems/stone_card.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const GemView = preload("res://view/gems/gem_view.gd")
const GemRock = preload("res://view/gems/gem_rock.gd")
const Appraisal = preload("res://view/gems/appraisal.gd")
const Roster = preload("res://view/home/roster.gd")

## How many tray stones the left column lists a page.
const TRAY_PAGE: int = 8

static func bar(home: Control, bar: HBoxContainer) -> void:
	## The top bar while coming home: where from, and how the run ended, in place of the tabs.
	var history: Array = home.profile.get("history", [])
	var last: Dictionary = history.back() if not history.is_empty() else {}
	var row := DeepUi.hbox(bar, 12)
	DeepUi.title(row, "Back from %s" % DeepContent.mine_name(str(last.get("mine", DeepContent.starter_mine()))), 20, DeepUi.PAPER)
	var outcome: String = str(last.get("outcome", "extracted"))
	var words: String = {"fallen": "fell at depth %d", "conquered": "conquered it, depth %d"}.get(outcome, "rode the lift at depth %d") % int(last.get("depth", 0))
	DeepUi.pill(row, {"fallen": "skull", "conquered": "crown"}.get(outcome, "lift"), words, DeepUi.BAD if outcome == "fallen" else DeepUi.GOOD, 12)
	if not home.profile.get("tray", []).is_empty():
		DeepUi.stat(row, "lock", "the workshop opens when the tray is empty", DeepUi.DIM, 12)

static func build(home: Control, content: VBoxContainer) -> void:
	bench(home, content, true)

static func bench(home: Control, content: VBoxContainer, holding: bool) -> void:
	var tray: Array = home.profile.get("tray", [])
	if not home.has_meta("came_with"):
		home.set_meta("came_with", int(home.profile.get("gold", 0)))
	if tray.is_empty():
		if holding:
			_done(home, content)
		return
	var pick: Dictionary = {}
	for stone in tray:
		if str(stone.id) == home._appraise_pick:
			pick = stone
	if pick.is_empty():
		## The first stone still to be read, or the first one waiting at all.
		for stone in tray:
			if not bool(stone.get("appraised", false)):
				pick = stone
				break
		if pick.is_empty():
			pick = tray[0]
		home._appraise_pick = str(pick.id)
	var columns := DeepUi.hbox(content, 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tray_column(home, columns, tray, holding)
	var known: bool = bool(pick.get("appraised", false))
	var owned: Dictionary = DeepProfile.owned(home.profile, str(pick.get("skill", ""))) if known else {}
	var middle := DeepUi.card(columns, Color(DeepUi.ACCENT, 0.35), 18)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(middle, 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	if known:
		_read_stone(home, box, pick, owned)
	else:
		_raw_stone(home, box, pick)
	home.enter(middle, 0.05)
	if known and not owned.is_empty():
		_yours(home, columns, owned)

static func _tray_column(home: Control, columns: HBoxContainer, tray: Array, holding: bool) -> void:
	var column := DeepUi.card(columns, DeepUi.LINE, 12)
	column.custom_minimum_size.x = 240
	var box := DeepUi.vbox(column, 6)
	DeepUi.section(box, "bag", "The tray · %d left" % tray.size())
	var rows := DeepUi.vbox(box, 6)
	var pager := DeepUi.hbox(box, 0)
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	for stone in home.paged(pager, "tray", tray, TRAY_PAGE):
		var id: String = str(stone.id)
		var known: bool = bool(stone.get("appraised", false))
		var fresh_skill: bool = known and DeepProfile.first_of_skill(home.profile, stone)
		var picked: bool = id == home._appraise_pick
		var tone: Color = StoneCard.PIP_NEW if fresh_skill else (DeepUi.ACCENT if picked else Color(0, 0, 0, 0))
		var row_panel := DeepUi.panel(rows, Color(DeepUi.ACCENT, 0.12) if picked else Color(1, 1, 1, 0.02), tone, 6, 6)
		if fresh_skill:
			var lit: StyleBoxFlat = row_panel.get_theme_stylebox("panel").duplicate()
			lit.set_border_width_all(2)
			lit.shadow_color = Color(StoneCard.PIP_NEW, 0.35)
			lit.shadow_size = 8
			row_panel.add_theme_stylebox_override("panel", lit)
		row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		row_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var row := DeepUi.hbox(row_panel, 8)
		StoneCard.mini(row, stone, 36)
		var words := DeepUi.vbox(row, 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(words, DeepUi.skill_name(stone) if known else DeepStone.raw_name(stone), 13, DeepUi.PAPER if known else DeepUi.MUTED)
		var state: String = "new skill" if fresh_skill else ("read" if known else "unread")
		DeepUi.label(words, state, 11, StoneCard.PIP_NEW if fresh_skill else DeepUi.DIM)
		if not DeepEconomy.commission_for(home.profile, stone).is_empty():
			DeepUi.icon(row, "flag", 15, DeepUi.GOOD, "A commission wants this stone")
		row_panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_tap", {"volume": 0.7})
				home._appraise_pick = id
				home._render())
	DeepUi.spacer(box, false)
	var raw: Array = tray.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)))
	if raw.size() > 1:
		var fee: int = 0
		for stone in raw:
			fee += DeepProfile.appraisal_fee(stone)
		var all := DeepUi.priced(DeepUi.icon_button(box, "loupe", "Read the rest", func() -> void: _read_all(home, raw), 13, DeepUi.INFO), str(fee))
		all.disabled = int(home.profile.get("gold", 0)) < fee
		all.tooltip_text = "Every unread stone, read at once." if not all.disabled else "You have %d gold. Reading the rest costs %d." % [int(home.profile.get("gold", 0)), fee]
	var cheapest: int = 1 << 30
	for stone in raw:
		cheapest = mini(cheapest, DeepProfile.appraisal_fee(stone))
	if not raw.is_empty() and int(home.profile.get("gold", 0)) < cheapest:
		var rough: int = 0
		for stone in raw:
			rough += DeepStone.rough_value(stone)
		var sell := DeepUi.icon_button(box, "scales", "Sell the unread rough", func() -> void:
			for stone in raw:
				DeepProfile.decide_tray(home.profile, str(stone.id), false)
			home._appraise_pick = ""
			home.profile_changed.emit(), 13, DeepUi.TRADE)
		DeepUi.priced(sell, "+%d" % rough)
		sell.tooltip_text = "You cannot pay to read them. A buyer pays for their size and color; you never learn what they were."
	var since: int = int(home.profile.get("gold", 0)) - int(home.get_meta("came_with", int(home.profile.get("gold", 0))))
	var tally := DeepUi.hbox(box, 6)
	DeepUi.label(tally, "Gold since you came up", 12, DeepUi.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(tally, "%+d" % since, 13, DeepUi.GOOD if since >= 0 else DeepUi.BAD)
	home.enter(column)

static func _raw_stone(home: Control, box: VBoxContainer, pick: Dictionary) -> void:
	## A raw stone in its rock under the loupe: pay to read it, or sell it as it is.
	var bench := LoupeBench.new(pick, 260.0)
	bench.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(bench)
	DeepUi.title(box, "A %s" % DeepStone.raw_name(pick).to_lower(), 26, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	var line := DeepUi.label(box, "Its skill, Cut and Clarity are hidden until it is read.", 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	line.name = "Line"
	var sheet := Appraisal.Sheet.new(_known(pick), {}, {"skill_text": true})
	sheet.visible = false
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sheet)
	var fee: int = DeepProfile.appraisal_fee(pick)
	var rough: int = DeepStone.rough_value(pick)
	var purse: int = int(home.profile.get("gold", 0))
	var choices := DeepUi.hbox(box, 14)
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	var read := DeepUi.primary(choices, "loupe", "Read it", func() -> void:
		var raw: Dictionary = pick.duplicate(true)
		if not DeepProfile.appraise(home.profile, pick):
			return
		home.touch()
		choices.visible = false
		line.text = "Under the loupe…"
		sheet.visible = true
		bench.play(sheet, raw, func() -> void:
			if DeepStone.is_fragile(pick):
				home._appraise_pick = ""
				home.cheer("Shattered: Fragile", DeepUi.BAD)
			home.profile_changed.emit()), 18, DeepUi.INFO)
	DeepUi.priced(read, str(fee), 16)
	read.custom_minimum_size = Vector2(230, 50)
	read.disabled = purse < fee
	DeepUi.voice(read, "loupe_spin")
	if purse < fee:
		read.tooltip_text = "You have %d gold. Reading this one costs %d." % [purse, fee]
		DeepUi.label(box, "You can't pay to read it. Sell it rough to clear the tray.", 13, DeepUi.BAD, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		DeepUi.breathe(read, 0.8, 1.6)
	var off := DeepUi.icon_button(choices, "scales", "Sell rough", func() -> void:
		var result: Dictionary = DeepProfile.decide_tray(home.profile, str(pick.id), false)
		home._appraise_pick = ""
		if bool(result.get("shattered", false)):
			home.cheer("Shattered: Fragile", DeepUi.BAD)
		home.profile_changed.emit(), 16, DeepUi.TRADE)
	DeepUi.priced(off, "+%d" % rough, 14)
	off.custom_minimum_size = Vector2(200, 50)
	off.tooltip_text = "Sells for what its color and size are worth. You never find out what it was."
	DeepUi.voice(off, "sell")

static func _known(raw: Dictionary) -> Dictionary:
	var known: Dictionary = raw.duplicate(true)
	known.appraised = true
	known.inclusions_revealed = true
	return known

static func _read_stone(home: Control, box: VBoxContainer, pick: Dictionary, owned: Dictionary) -> void:
	## A known stone: what there is to say about it across the top, the stone under the loupe
	## beside its lines against the one kept (side by side, so a long read never pushes the
	## choice off the page), and the choice.
	var words := DeepUi.vbox(box, 6)
	words.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var skill_name: String = str(DeepStone.skill_of(pick).get("name", "stone"))
	if owned.is_empty() and DeepProfile.first_of_skill(home.profile, pick):
		var fanfare := DeepUi.hbox(words, 10)
		var star := DeepUi.pill(fanfare, "star", "New skill", StoneCard.PIP_NEW, 15)
		if home._fresh and not home._headless:
			DeepUi.breathe(star, 0.7, 1.4)
		DeepUi.wrap(words, "Your first %s. A first stone is never sold: it lights up its place in the vault." % skill_name, 14, DeepUi.GOOD, HORIZONTAL_ALIGNMENT_LEFT, 420)
	elif not owned.is_empty():
		DeepUi.stat(words, "scales", "Only one of each skill can be kept. Which %s goes in the vault?" % skill_name, DeepUi.INFO, 14)
	var wanted: Dictionary = DeepEconomy.commission_for(home.profile, pick)
	if not wanted.is_empty():
		DeepUi.stat(words, "flag", "A commission wants this %s: %d gold" % [skill_name, DeepEconomy.payout(wanted, pick)], DeepUi.GOOD, 14)
	var top := DeepUi.hbox(box, 18)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	var lens := HomeParts.LoupeTable.new(pick, 140.0 if not owned.is_empty() else 170.0)
	lens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lens)
	var sheet := Appraisal.Sheet.new(pick, owned, {"skill_text": true, "owned_picture": false})
	sheet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(sheet)
	sheet.show_all()
	DeepUi.spacer(box, false)
	Appraisal.choices(box, actions(home, pick))

static func _yours(home: Control, columns: HBoxContainer, owned: Dictionary) -> void:
	## The stone of its skill already kept, the size and light of the one being weighed.
	var card := DeepUi.card(columns, Color(DeepUi.tier_color(str(DeepStone.grade(owned).tier)), 0.45), 14)
	card.custom_minimum_size.x = 320
	var box := DeepUi.vbox(card, 8)
	DeepUi.section(box, "chest", "Yours")
	var lens := HomeParts.LoupeTable.new(owned, 150.0)
	lens.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(lens)
	StoneCard.build(box, owned, {"picture": false, "provenance": true, "value": true, "text_width": 280})
	var wearing: Array = []
	for key in home.profile.get("characters", {}):
		if home.profile.characters[key].get("rail", []).has(str(owned.get("skill", ""))):
			wearing.append(str(key))
	if not wearing.is_empty():
		var row := DeepUi.hbox(box, 6)
		for key in wearing:
			row.add_child(Roster.Portrait.new(key, Vector2(24, 24)))
		DeepUi.label(row, "In %s" % ", ".join(wearing.map(func(k: Variant) -> String: return str(DeepContent.character(str(k)).get("name", k)))), 12, DeepUi.MUTED)
	DeepUi.pop_in(card, 0.15, 0.94, 0.35)

static func actions(home: Control, pick: Dictionary) -> Array:
	## What can be done with a known stone on the tray. With one of its skill already kept the
	## choice is which of the two to keep, and only the one not kept can be sold: keeping the
	## new one lets the old one go for nothing. Otherwise it is keep (a first is never sold).
	var id: String = str(pick.id)
	if DeepStone.is_fragile(pick):
		return []
	var owned: Dictionary = DeepProfile.owned(home.profile, str(pick.skill))
	var keep := func() -> void:
		DeepProfile.decide_tray(home.profile, id, true)
		home._appraise_pick = ""
		home.cheer("Kept in the vault", DeepUi.GOOD)
		home.profile_changed.emit()
	var sell := func() -> void:
		DeepProfile.decide_tray(home.profile, id, false)
		home._appraise_pick = ""
		home.profile_changed.emit()
	var out: Array = []
	if owned.is_empty():
		out.append({"label": "Into the vault", "glyph": "chest", "tone": DeepUi.GOOD, "caption": "The first of its skill is never sold", "call": keep, "sound": "keep"})
	else:
		out.append({"label": "Keep it, replace yours", "glyph": "chest", "tone": DeepUi.GOOD, "caption": "Yours is let go for no gold", "call": keep, "sound": "keep"})
		out.append({"label": "Sell it", "glyph": "scales", "tone": DeepUi.TRADE, "price": "+%d" % DeepStone.value(pick), "caption": "Yours stays", "call": sell, "sound": "sell"})
	var wanted: Dictionary = DeepEconomy.commission_for(home.profile, pick)
	if not wanted.is_empty():
		var paid: int = DeepEconomy.payout(wanted, pick)
		var commission_id: String = str(wanted.id)
		out.append({"label": "Turn it in", "glyph": "flag", "tone": DeepUi.INFO, "price": "+%d" % paid, "caption": "For a commission", "sound": "sell",
			"call": func() -> void:
				if bool(DeepEconomy.turn_in(home.profile, id, commission_id).get("ok", false)):
					home._appraise_pick = ""
					home.profile_changed.emit()})
	return out

static func _read_all(home: Control, raw: Array) -> void:
	var shattered: int = 0
	var best: Dictionary = {}
	for stone in raw:
		if not DeepProfile.appraise(home.profile, stone):
			continue
		if DeepStone.is_fragile(stone):
			shattered += 1
			continue
		if best.is_empty() or DeepStone.value(stone) > DeepStone.value(best):
			best = stone
	if not best.is_empty():
		DeepAudio.reveal_stone(best)
		home._appraise_pick = str(best.id)
	if shattered > 0:
		home.cheer("%s shattered: Fragile" % DeepUi.plural(shattered, "stone"), DeepUi.BAD)
	home.profile_changed.emit()

static func _done(home: Control, content: VBoxContainer) -> void:
	## Every stone decided: what the tray came to, and the way into the workshop.
	var holder := DeepUi.center(content)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := DeepUi.card(holder, Color(DeepUi.ACCENT, 0.5), 30)
	var box := DeepUi.vbox(card, 12)
	var mark := DeepUi.icon(box, "chest", 64, DeepUi.ACCENT)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DeepUi.title(box, "The tray is clear", 28, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	var since: int = int(home.profile.get("gold", 0)) - int(home.get_meta("came_with", int(home.profile.get("gold", 0))))
	DeepUi.label(box, ("%+d gold since you came up." % since) if since != 0 else "Every stone is decided.", 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var go := DeepUi.primary(box, "chest", "Into the workshop", func() -> void:
		home.profile.erase("homecoming")
		home.remove_meta("came_with")
		home._appraise_pick = ""
		home.open("descend")
		home.profile_changed.emit(), 18)
	go.custom_minimum_size = Vector2(300, 52)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	DeepUi.breathe(go, 0.82, 1.8)
	home.enter(card)

class LoupeBench extends Control:
	## A raw stone in its rock under the loupe, read right here: the rock comes off a chunk at
	## a time, the light inside finds the cracks, the last chunk splits away, and the sheet
	## beside it is read out line by line. A click skips to the end.
	var stone: Dictionary
	var _view: Control
	var _clock: float = 0.0
	var _tone: Color
	var _lamp: TextureRect
	var _sheet: Control
	var _done: Callable
	var _tweens: Array = []
	var _finished: bool = false

	func _init(raw: Dictionary, edge: float) -> void:
		stone = raw
		custom_minimum_size = Vector2(edge * 1.3, edge)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_tone = DeepUi.color(DeepStone.color(stone))
		_lamp = DeepUi.glow(self, _tone, 0.12, 1.1)
		_view = GemView.new()
		var reach: float = edge * 0.8
		_view.anchor_left = 0.5
		_view.anchor_right = 0.5
		_view.anchor_top = 0.5
		_view.anchor_bottom = 0.5
		_view.offset_left = -reach * 0.5
		_view.offset_right = reach * 0.5
		_view.offset_top = -reach * 0.5
		_view.offset_bottom = reach * 0.5
		_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view.set_drift(true)
		_view.set_spin(0.4)
		var sealed: Dictionary = raw.duplicate(true)
		sealed.appraised = false
		_view.configure(sealed)
		add_child(_view)

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		var radius: float = size.y * 0.47
		draw_circle(centre, radius, Color(0.02, 0.025, 0.035, 0.85))
		draw_arc(centre, radius, 0, TAU, 72, Color("b8a47a"), 5.0, true)
		draw_arc(centre, radius - 6.0, 0, TAU, 72, Color("5a4a30"), 2.0, true)
		for i in range(24):
			var angle: float = TAU * float(i) / 24.0 + _clock * 0.1
			draw_line(centre + Vector2.from_angle(angle) * (radius + 3.0), centre + Vector2.from_angle(angle) * (radius + 9.0), Color("b8a47a", 0.8), 1.5, true)
		var sweep: float = fmod(_clock * 0.4, 1.0) * TAU
		draw_arc(centre, radius - 12.0, sweep, sweep + 0.5, 16, Color(1, 1, 1, 0.25), 3.0, true)

	func play(sheet: Control, raw: Dictionary, done: Callable) -> void:
		_sheet = sheet
		_done = done
		if GemView.headless() or not is_inside_tree():
			_finish()
			return
		var count: int = maxi(1, int(_view.call("chunks_left")))
		var beat := create_tween()
		_tweens.append(beat)
		var swing: float = clampf(2.4 / float(maxi(1, count - 1)), 0.35, 0.8)
		for index in range(count - 1):
			beat.tween_callback(_chip.bind(index, count))
			beat.tween_interval(swing)
		beat.tween_callback(func() -> void:
			DeepAudio.play("loupe_spin")
			var t := create_tween()
			_tweens.append(t)
			t.tween_method(func(v: float) -> void:
				_view.call("set_spin", lerpf(2.0, 11.0, v))
				_view.call("glow_cracks", lerpf(0.35, 1.5, v))
				_lamp.modulate.a = lerpf(0.3, 0.8, v), 0.0, 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN))
		beat.tween_interval(1.15)
		beat.tween_callback(_break_open)
		beat.tween_interval(0.8)
		for part in sheet.call("parts"):
			beat.tween_callback(func() -> void: sheet.call("reveal", part))
			beat.tween_interval(float(Appraisal.PAUSES.get(str(part).get_slice(":", 0), 0.7)) * 0.7)
		beat.tween_callback(_finish)

	func _chip(index: int, count: int) -> void:
		var at: Vector2 = _view.position + _view.call("knock_chunk")
		DeepAudio.play("chisel", {"volume": 0.9})
		DeepUi.burst(self, at, GemRock.TONE.lightened(0.25), 18, 260.0, 0.6, 4.0)
		DeepUi.shake(self, 4.0, 0.2)
		var share: float = float(index + 1) / float(count)
		_view.call("glow_cracks", 0.12 + 0.2 * share)
		_view.call("set_spin", 0.5 + 1.5 * share)

	func _break_open() -> void:
		var known: Dictionary = stone.duplicate(true)
		known.appraised = true
		known.inclusions_revealed = true
		_view.call("configure", known)
		DeepAudio.play("rock_break", {"volume": 0.9})
		DeepAudio.play("gleam", {"delay": 0.04})
		var heart: Vector2 = _view.position + _view.call("centre_point")
		DeepUi.burst(self, heart, _tone.lightened(0.3), 70, 460.0, 1.1, 8.0)
		DeepUi.burst(self, heart, Color.WHITE, 30, 300.0, 0.9, 5.0)
		DeepUi.shake(self, 7.0, 0.3)
		var t := create_tween()
		_tweens.append(t)
		t.tween_method(func(spin: float) -> void: _view.call("set_spin", spin), 11.0, 0.45, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and _done.is_valid():
			_finish()

	func _finish() -> void:
		if _finished:
			return
		_finished = true
		for t in _tweens:
			if t != null and t.is_valid():
				t.kill()
		if _sheet != null and is_instance_valid(_sheet):
			_sheet.call("show_all")
		DeepAudio.reveal_stone(stone)
		if _done.is_valid():
			_done.call()
