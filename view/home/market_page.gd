extends RefCounted
## The Market: everything bought or paid for. Today's Geode and the week's down the left; the
## case of cut and read stones in the middle, with the bench under it (the Wheel, the Oven and
## the trade-up contract, each once a day); the day's commissions down the right. Restock
## replaces today's Geode and the case once a day, for gold. The Wheel, the Oven and the
## contract each open a page of their own; Escape or the way back returns to the counter.

const HomeParts = preload("res://view/home/home_parts.gd")
const StoneBrowser = preload("res://view/home/stone_browser.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Geode = preload("res://view/gems/geode.gd")
const GeodeMesh = preload("res://view/gems/geode_mesh.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const Rework = preload("res://view/gems/rework.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

## How many vault stones the Wheel's and the Oven's picker shows a page: three rows.
const PICK_PAGE: int = 33
## How many stones the contract bench's picker shows a page: four rows of five.
const CONTRACT_PAGE: int = 20
## The size of a place on the contract bench.
const CONTRACT_SLOT := Vector2(150, 176)
## How tall the lamp over each stone in the case is: short enough that the bench fits under
## the case with a stone's longest rules and three inclusions a line each.
const CASE_LAMP: float = 190.0
## How large the stone on the Wheel and in the Oven is drawn; a heavy one hangs well past it,
## so the room it stands in grows with the column.
const REWORK_EDGE: float = 150.0
## The violet an inclusion is written in, on the case and in the Oven.
const INCLUSION_TONE := Color("c58bff")

static func build(home: Control, content: VBoxContainer) -> void:
	if not bool(home.profile.get("daily", {}).get("market_seen", false)) and home.profile.get("daily", null) is Dictionary:
		## Looking is enough: the Market's pip goes once it has been seen today.
		home.profile.daily.market_seen = true
		home.call_deferred("touch")
	match home._market_view:
		"wheel", "oven":
			_rework_page(home, content, "cut" if home._market_view == "wheel" else "clarity")
		"contract":
			_contract_page(home, content)
		_:
			_counter(home, content)

static func _head(home: Control, content: VBoxContainer, title: String, back: bool) -> HBoxContainer:
	var head := DeepUi.hbox(content, 12)
	if back:
		var way := DeepUi.icon_button(head, "prev", "Market", func() -> void:
			home._market_view = "main"
			home._render(), 14, DeepUi.MUTED)
		way.tooltip_text = "Back to the counter (Esc)"
		DeepUi.voice(way, "ui_back")
	else:
		DeepUi.icon(head, "geode", 28, DeepUi.ACCENT)
	DeepUi.title(head, title, 30, DeepUi.PAPER)
	DeepUi.spacer(head)
	home.enter(head)
	return head

# --- the counter -------------------------------------------------------------------------------------

static func _counter(home: Control, content: VBoxContainer) -> void:
	## Back at the counter, the Wheel's and the Oven's pages have been left: their last result
	## and the place held for the stone in their picker go.
	home._rework_done = {}
	home._rework_hold = {}
	var head := _head(home, content, "The market", false)
	var left: int = DeepEconomy.seconds_to_tomorrow()
	DeepUi.stat(head, "hourglass", "New stock in %dh %02dm" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 13, "Today's Geode, the case and the commissions turn over at midnight UTC.")
	var price: int = DeepEconomy.restock_price()
	var done: bool = DeepEconomy.restocked_today(home.profile)
	var restock := DeepUi.icon_button(head, "reroll", "Restocked today" if done else "Restock now", func() -> void:
		if bool(DeepEconomy.restock(home.profile).get("ok", false)):
			DeepAudio.play("buy")
			home.profile_changed.emit(), 13, DeepUi.PAPER)
	if not done:
		DeepUi.priced(restock, str(price))
		home.gold_gate(restock, price)
	restock.disabled = done or int(home.profile.get("gold", 0)) < price
	restock.tooltip_text = "Once a day: a new Geode of the day and a new case of cut stones. The week's Geode and the commissions stay." if not done else "The market can be restocked once a day."
	var columns := DeepUi.hbox(content, 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_geodes(home, columns)
	var middle := DeepUi.vbox(columns, 14)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## The case and the commissions are parts of their own (see home.region): a stone bought
	## or a commission swapped redraws them and the purse, not the counter.
	var case_box := DeepUi.vbox(middle, 0)
	case_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home.region(case_box, "market_case", func(holder: Control) -> void: _case(home, holder))
	_bench(home, middle)
	var right := DeepUi.vbox(columns, 14)
	right.custom_minimum_size.x = 340
	var commission_box := DeepUi.vbox(right, 0)
	commission_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home.region(commission_box, "market_commissions", func(holder: Control) -> void: _commissions(home, holder))

static func _favorite_in(home: Control, skills: Array) -> bool:
	var favorites: Array = DeepProfile.favorites(home.profile)
	return skills.any(func(k: Variant) -> bool: return favorites.has(str(k)))

static func _geodes(home: Control, columns: HBoxContainer) -> void:
	var panel := DeepUi.card(columns, DeepUi.LINE, 12)
	panel.custom_minimum_size.x = 300
	var box := DeepUi.vbox(panel, 10)
	DeepUi.section(box, "geode", "Geodes")
	var shelf: Array = DeepEconomy.shelf(home.profile)
	if shelf.is_empty():
		DeepUi.wrap(box, "Geodes come from the mines you have opened.", 13, DeepUi.DIM)
	for geode in shelf:
		_geode_card(home, box, geode)
	## A Geode gone from the shelf (restocked, a new day) is let go with its view.
	home.let_go_kept("shelf|", shelf.map(func(g: Dictionary) -> String: return _shelf_key(g)))
	home.enter(panel, 0.05)

static func _shelf_key(geode: Dictionary) -> String:
	return "shelf|" + GeodeMesh.key_of(geode, Geode.theme_tone(geode))

static func _shelf_art(home: Control, geode: Dictionary) -> Control:
	## A shelf Geode's own 3D view, kept from one drawing of the counter to the next
	## (home.kept): each is a world of its own, with shadows, contact shade and glow, and the
	## shelf is drawn again on every visit and every purchase.
	var tone: Color = Geode.theme_tone(geode)
	return home.kept(_shelf_key(geode), func() -> Control: return Geode.Art.new(geode, tone))

static func prewarm(home: Control) -> void:
	## Readies what the Market shows before it is first opened, while the workshop is being
	## looked at: the case's photographs are taken, and the shelf's Geodes are cut and drawn
	## for a few frames off the edge of the screen, then put aside for the counter to take.
	## A first open on a cold start compiled everything a Geode is drawn with and stopped the
	## game for a second and more.
	for entry in DeepEconomy.case_stones(home.profile):
		var stone: Dictionary = entry.get("stone", {})
		if not stone.is_empty():
			Thumbs.request(Thumbs.gem_key(stone), "gem", {"stone": stone}, func(_texture: Texture2D) -> void: pass)
	var parked: Array = []
	for geode in DeepEconomy.shelf(home.profile):
		var art: Control = _shelf_art(home, geode)
		if art.get_parent() != null:
			continue
		art.position = Vector2(-6000.0 - 400.0 * parked.size(), -6000.0)
		art.size = Vector2(276, 130)
		home.add_child(art)
		parked.append(art)
	var tree: SceneTree = home.get_tree()
	## Until each is cut (on a worker) and has drawn a few frames, or the counter has taken it.
	var drawn: int = 0
	for _i in range(300):
		await tree.process_frame
		var waiting: bool = parked.any(func(art: Variant) -> bool:
			return is_instance_valid(art) and (art as Node).get_parent() == home and (art.get("_built") as Dictionary).is_empty())
		drawn = 0 if waiting else drawn + 1
		if drawn >= 6:
			break
	for art in parked:
		if is_instance_valid(art) and (art as Node).get_parent() == home:
			home.remove_child(art)

static func _geode_card(home: Control, parent: Node, geode: Dictionary) -> void:
	var weekly: bool = bool(geode.get("weekly", false))
	var bought: bool = bool(geode.get("bought", false))
	var tone: Color = Geode.theme_tone(geode)
	var card := DeepUi.card(parent, Color(DeepUi.ACCENT if weekly else tone, 0.55 if not bought else 0.2), 10, DeepUi.GLASS)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## Right-click for the close look, the way a stone or a die opens: the Geode turned by hand
	## and its odds in full.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "Right-click for what it can hold, and how likely each thing is"
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			load("res://view/inspect/inspector.gd").geode(geode, {"profile": home.profile})
			card.accept_event())
	var box := DeepUi.vbox(card, 6)
	var tag := DeepUi.hbox(box, 6)
	var kind: String = ("This week's Geode" if weekly else "Today's Geode")
	DeepUi.heading(tag, kind, 11, DeepUi.ACCENT if weekly else tone).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if weekly:
		DeepUi.label(tag, DeepUi.plural(DeepEconomy.featured_days_left(DeepEconomy.today()), "day") + " left", 11, DeepUi.DIM)
	else:
		DeepUi.label(tag, "one color" if str(geode.get("kind", "")) == "color" else "one mine", 11, DeepUi.DIM)
	var art: Control = _shelf_art(home, geode)
	art.position = Vector2.ZERO
	art.custom_minimum_size = Vector2(0, 110)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	art.set("open", bought)
	## Back on the page, a still one (opened) is drawn again where it now stands.
	art.call("_redraw")
	## A view kept from the last drawing may have been leaning to a Crack it button that is gone.
	_still(art)
	art.set("hover", 0.0)
	var lean := func(to: float, seconds: float) -> void:
		if not is_instance_valid(art):
			return
		_still(art)
		var tween := art.create_tween()
		tween.tween_property(art, "hover", to, seconds)
		art.set_meta("lean", tween)
	DeepUi.title(box, Geode.geode_name(geode), 18, tone.lightened(0.2) if not bought else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var line := DeepUi.label(box, Geode.geode_line(geode), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 250
	var facts := DeepUi.hbox(box, 6)
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	var odds: Dictionary = DeepEconomy.geode_odds(geode)
	var carats: Array = odds.get("carat", [1, 1])
	DeepUi.pill(facts, "carat", "%d to %d ct" % [int(carats[0]), int(carats[1])], DeepUi.ACCENT, 11)
	if weekly:
		DeepUi.pill(facts, "cut", DeepEconomy.need_text({"kind": "cut", "value": int(DeepContent.constant("geode_week_min_cut", 3))}), DeepUi.INFO, 11)
	if _favorite_in(home, DeepEconomy.geode_pool(geode)):
		DeepUi.pill(facts, "star", "favorite", DeepUi.ACCENT_HI, 11, "It can hold one of your favorites, starred in the vault.")
	var foot := DeepUi.hbox(box, 6)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	if bought:
		var held: Dictionary = geode.get("stone", {}).duplicate(true)
		held.appraised = true
		StoneCard.mini(foot, held, 32)
		DeepUi.label(foot, "Opened", 12, DeepUi.DIM)
		return
	var price: int = int(geode.get("price", 0))
	var crack := DeepUi.priced(DeepUi.primary(foot, "hammer", "Crack it", func() -> void: crack_geode(home, geode), 14, DeepUi.INFO), str(price))
	DeepUi.voice(crack, "geode_crack")
	crack.disabled = int(home.profile.get("gold", 0)) < price
	home.gold_gate(crack, price)
	crack.tooltip_text = "Buys it and cracks it open, three blows." if not crack.disabled else "You have %d gold. This Geode costs %d." % [int(home.profile.get("gold", 0)), price]
	crack.mouse_entered.connect(func() -> void:
		if not crack.disabled:
			lean.call(1.0, 0.2))
	crack.mouse_exited.connect(func() -> void: lean.call(0.0, 0.3))

static func _still(art: Control) -> void:
	## Stops a shelf Geode's lean toward its Crack it button where it is.
	var tween: Variant = art.get_meta("lean") if art.has_meta("lean") else null
	if tween is Tween and (tween as Tween).is_valid():
		(tween as Tween).kill()

static func crack_geode(home: Control, geode: Dictionary) -> void:
	## Pays for a Geode and cracks it: the stone is on the tray before the first blow, so the
	## ceremony is only the showing, and the choice at its end is made on the spot.
	var opened: Dictionary = DeepEconomy.open_geode(home.profile, str(geode.get("id", "")))
	if not bool(opened.get("ok", false)):
		return
	var made: Dictionary = opened.stone
	home.touch()
	Geode.open(opened.geode, made, {"actions": found_actions(home, made), "owned": DeepProfile.owned(home.profile, str(made.get("skill", "")))}, func() -> void: home.profile_changed.emit())
	if DeepUi.headless():
		home.profile_changed.emit()

static func found_actions(home: Control, made: Dictionary) -> Array:
	## What can be done the moment a Geode's or a contract's stone is read: the tray's own
	## choices, and a way out that leaves it waiting in the vault's Unappraised view.
	var Homecoming: Script = load("res://view/home/homecoming.gd")
	var out: Array = Homecoming.actions(home, made)
	out.append({"label": "Decide later", "glyph": "chest", "primary": false, "dismiss": true, "caption": "It waits in the vault, unappraised",
		"call": func() -> void: home.profile_changed.emit()})
	return out

static func _case(home: Control, middle: VBoxContainer) -> void:
	var panel := DeepUi.card(middle, DeepUi.LINE, 12)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(panel, 10)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "gem", "Cut and read today").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(head, "Hold Shift over one to compare it with yours", 12, DeepUi.DIM)
	var row := DeepUi.hbox(box, 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stock: Array = DeepEconomy.case_stones(home.profile)
	if stock.is_empty():
		DeepUi.wrap(row, "The case is stocked from the mines you have opened.", 13, DeepUi.DIM)
	var favorites: Array = DeepProfile.favorites(home.profile)
	## Each card's inclusion lines and the room at its foot, handed out once the case is laid
	## out (`_spread_reads`).
	var spread: Array = []
	for entry in stock:
		var stone: Dictionary = entry.stone
		var skill: String = str(stone.get("skill", ""))
		var sold: bool = bool(entry.get("bought", false))
		var own: Dictionary = DeepProfile.owned(home.profile, skill)
		var grade: Dictionary = DeepStone.grade(stone)
		var card := DeepUi.card(row, Color(DeepUi.tier_color(str(grade.tier)), 0.45 if not sold else 0.15), 10, Color(0.05, 0.07, 0.12, 0.9))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var column := DeepUi.vbox(card, 5)
		var picture := DeepUi.center(column)
		## A photograph under the lamp, alive only while the pointer rests on it: three live
		## stones were built again on every visit and drawn on every frame the counter was open.
		var lamp := HomeParts.Showcase.new(stone, CASE_LAMP, 0.92, false)
		picture.add_child(lamp)
		if sold:
			lamp.modulate = Color(1, 1, 1, 0.35)
		var names := DeepUi.hbox(column, 6)
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.label(names, DeepUi.skill_name(stone), 16, DeepUi.color(DeepStone.color(stone)).lightened(0.2) if not sold else DeepUi.DIM)
		DeepUi.label(names, str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), 12, DeepUi.tier_color(str(grade.tier)))
		if favorites.has(skill):
			DeepUi.icon(names, "star", 14, DeepUi.ACCENT_HI, "One of your favorites")
		DeepUi.label(column, "%d ct · %s · %s" % [int(stone.get("carat", 1)), DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.clarity_name(int(stone.get("clarity", 0)))], 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		## What it does, so a stone can be bought without leaving the counter to look it up.
		var rules := DeepUi.panel(column, Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.07), 6, 8)
		var rule_box := DeepUi.vbox(rules, 6)
		var trigger: Dictionary = DeepStone.skill_of(stone).get("trigger", {"kind": "always"})
		var need := DeepUi.center(rule_box)
		DiceIcons.build(need, DeepPatterns.describe(trigger, int(DeepStone.effective(stone, {}).cut_step)), 18, DeepUi.PAPER)
		DeepUi.effect_text(rule_box, DeepStone.text(stone, {}), 12, DeepUi.PAPER if not sold else DeepUi.DIM)
		var lines_from: int = rule_box.get_child_count()
		StoneCard.carat_lines(rule_box, stone, {}, 11)
		## A heavy stone's carat line ("Four times over, for its weight.") wraps under its
		## mark rather than widen the case.
		for at in range(lines_from, rule_box.get_child_count()):
			var value: Node = rule_box.get_child(at).get_node_or_null("Value")
			if value is Label:
				(value as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				(value as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var reads: Array = []
		for key in stone.get("inclusions", []):
			var inclusion: Dictionary = DeepContent.inclusion(str(key))
			var read := DeepUi.wrap(rule_box, "%s: %s" % [str(inclusion.get("name", key)), str(inclusion.get("text", ""))], 11, INCLUSION_TONE)
			## A line each to begin with: read out in full beside a heavy stone's long rules, at
			## the small window's text floor, three of them pushed the bench off the page. The
			## room the card has left is handed out once it is laid out (`_spread_reads`), and
			## whatever is still cut short shows whole on hover.
			read.max_lines_visible = 1
			read.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			read.mouse_filter = Control.MOUSE_FILTER_PASS
			var whole: String = str(key)
			Tips.attach(read, func() -> Variant:
				if not is_instance_valid(read) or read.get_line_count() <= read.max_lines_visible:
					return null
				return _inclusion_plate(whole))
			reads.append(read)
		var room := DeepUi.spacer(column, false)
		if not reads.is_empty():
			spread.append({"reads": reads, "room": room})
		_yours_beside(column, stone, own)
		var id: String = str(entry.get("id", ""))
		if sold:
			DeepUi.label(column, "Sold", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var purchase := func() -> void:
				var bought: Dictionary = DeepEconomy.buy_case(home.profile, id)
				if bool(bought.get("ok", false)):
					DeepAudio.play("keep")
					home.cheer("%s into the vault" % DeepUi.skill_name(stone), DeepUi.GOOD)
					## The vault gained it: what the commissions can be filled with changes too.
					home.changed(["market_case", "market_commissions"])
			## Its close look says what the case asks as well as what it is worth, with a Buy.
			lamp.inspect_with({"market": {"price": int(entry.price), "buy": purchase, "gold": func() -> int: return int(home.profile.get("gold", 0)),
				"replaces": not own.is_empty()}})
			var buy := DeepUi.icon_button(column, "chest", "Buy", purchase, 14, DeepUi.PAPER)
			DeepUi.priced(buy, str(int(entry.price)))
			buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			buy.disabled = int(home.profile.get("gold", 0)) < int(entry.price)
			home.gold_gate(buy, int(entry.price))
			buy.tooltip_text = ("It goes into your vault%s." % (" in place of yours, which is let go for no gold" if not own.is_empty() else "")) if not buy.disabled else "You have %d gold." % int(home.profile.get("gold", 0))
			DeepUi.voice(buy, "buy")
		card.mouse_entered.connect(func() -> void: home.hover_stone(card, stone))
	if not spread.is_empty():
		## Again whenever the case itself changes size (the window does).
		panel.resized.connect(func() -> void: _spread_reads(panel, spread))
		_spread_reads(panel, spread)
	home.enter(panel, 0.08)

static func _spread_reads(panel: Control, cards: Array) -> void:
	## Hands the room left at the foot of each case card to its inclusions, a line at a time and
	## the first one first, so a light stone's one rule is read out whole and a heavy stone's
	## three still fit. Every line is put back to one, the case is let settle for two frames,
	## and only then is each card's room read: measured on a settled page it is exact, so no
	## card grows past the row it stands in and the page never grows. (Worked out while the
	## page was still being laid out, the three cards fed each other's sizes back and forth
	## without end.) `cards`: [{reads, room}].
	if bool(panel.get_meta("spreading", false)) or not panel.is_inside_tree():
		return
	panel.set_meta("spreading", true)
	for card in cards:
		for read in card.reads:
			_show_lines(read, 1)
	var tree: SceneTree = panel.get_tree()
	for _i in range(2):
		await tree.process_frame
	if not is_instance_valid(panel):
		return
	## Settled to the same size time after time, the case is only being resized by its own
	## lines: it is left with a line each rather than go round for ever.
	var settled: Vector2 = panel.size
	var again: bool = panel.has_meta("settled") and (panel.get_meta("settled") as Vector2).is_equal_approx(settled)
	panel.set_meta("settled", settled)
	panel.set_meta("repeats", int(panel.get_meta("repeats", 0)) + 1 if again else 0)
	if int(panel.get_meta("repeats")) >= 3:
		panel.set_meta.call_deferred("spreading", false)
		return
	for card in cards:
		var free: float = (card.room as Control).size.y if is_instance_valid(card.room) else 0.0
		for read in card.reads:
			if not is_instance_valid(read):
				continue
			var step: float = _line_step(read)
			var extra: int = clampi(floori(free / maxf(1.0, step)), 0, maxi(0, (read as Label).get_line_count() - 1))
			free -= float(extra) * step
			_show_lines(read, 1 + extra)
	## The case does not change size for what was handed out inside it; a resize from here on
	## is the window's.
	panel.set_meta.call_deferred("spreading", false)

static func _show_lines(read: Variant, lines: int) -> void:
	if not is_instance_valid(read) or (read as Label).max_lines_visible == lines:
		return
	(read as Label).max_lines_visible = lines
	## The engine does not tell the containers that a label's least height moved with its line
	## limit: told here, or the card keeps the label a line high.
	(read as Label).update_minimum_size()

static func _line_step(label: Label) -> float:
	## How much taller a label grows for one more line.
	return float(label.get_line_height()) + float(label.get_theme_constant("line_spacing"))

static func _inclusion_plate(key: String) -> Control:
	## An inclusion read out whole, on hover: its name and its rule.
	var inclusion: Dictionary = DeepContent.inclusion(key)
	return Plates.words(str(inclusion.get("name", key)), str(inclusion.get("text", "")), "Inclusion", INCLUSION_TONE)

static func _yours_beside(parent: Node, stone: Dictionary, own: Dictionary) -> void:
	## The stone of the same skill already in the vault, set beside one for sale: its grade,
	## its marks and how far the one on offer is above or below it.
	var plate := DeepUi.panel(parent, Color(0, 0, 0, 0.22), Color(1, 1, 1, 0.06), 6, 6)
	var row := DeepUi.hbox(plate, 8)
	if own.is_empty():
		DeepUi.icon(row, "spark", 18, StoneCard.PIP_NEW)
		DeepUi.label(row, "New!", 12, StoneCard.PIP_NEW)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		return
	StoneCard.mini(row, own, 38.0)
	var words := DeepUi.vbox(row, 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grade: Dictionary = DeepStone.grade(own)
	var names := DeepUi.hbox(words, 6)
	DeepUi.label(names, "Yours", 12, DeepUi.MUTED)
	DeepUi.label(names, "%s · %d" % [str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), int(grade.score)], 12, DeepUi.tier_color(str(grade.tier)))
	var stats := DeepUi.label(words, "%d ct · %s · %s" % [int(own.get("carat", 1)), DeepContent.cut_name(int(own.get("cut", 0))), DeepContent.clarity_name(int(own.get("clarity", 0)))], 11, DeepUi.DIM)
	## A heavy stone of the longest Cut and Clarity gives way rather than widen the case: three
	## such plates side by side would push the counter past the page.
	stats.clip_text = true
	stats.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var gap: int = int(DeepStone.grade(stone).score) - int(grade.score)
	var tone: Color = DeepUi.GOOD if gap > 0 else (DeepUi.BAD if gap < 0 else DeepUi.MUTED)
	var lead := DeepUi.label(row, "%+d" % gap if gap != 0 else "even", 15, tone)
	lead.tooltip_text = "The one on offer grades %s yours." % ("above" if gap > 0 else ("below" if gap < 0 else "level with"))
	lead.mouse_filter = Control.MOUSE_FILTER_PASS

static func _bench(home: Control, parent: VBoxContainer) -> void:
	var panel := DeepUi.card(parent, DeepUi.LINE, 12)
	var box := DeepUi.vbox(panel, 8)
	DeepUi.section(box, "hammer", "The bench · once a day each")
	## Three tiles in a row under the case: a short line each, the whole of it on hover.
	var row := DeepUi.hbox(box, 10)
	var services: Array = [["wheel", "cut", "The Wheel", "New Cut · 1 in 25 break", "Recut a vault stone's Cut. It always changes, up or down, and 1 in 25 stones break on the wheel."],
		["oven", "flame", "The Oven", "New Clarity · 1 in 25 break", "Refire a vault stone's Clarity. It, and what is frozen inside, always changes, and 1 in 25 stones break in the oven."],
		["contract", "contract", "Trade-up contract", "Five stones in, one finer out", "Five stones of one grade go in; one of the next grade comes out."]]
	for entry in services:
		var view: String = str(entry[0])
		var used: bool = DeepEconomy.contract_signed_today(home.profile) if view == "contract" else DeepEconomy.rework_used(home.profile, "cut" if view == "wheel" else "clarity")
		var card := DeepUi.choice_card(row, DeepUi.ACCENT, func() -> void:
			home._market_view = view
			home._render(), 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = str(entry[4])
		var top := DeepUi.hbox(card, 10)
		top.mouse_filter = Control.MOUSE_FILTER_PASS
		DeepUi.icon(top, str(entry[1]), 24, DeepUi.ACCENT if not used else DeepUi.DIM).mouse_filter = Control.MOUSE_FILTER_PASS
		var words := DeepUi.vbox(top, 1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.title(words, str(entry[2]), 16, DeepUi.PAPER if not used else DeepUi.MUTED)
		var line := DeepUi.label(words, "Used today" if used else str(entry[3]), 12, DeepUi.DIM if used else DeepUi.MUTED)
		## The line gives way rather than widen the case above it.
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if not used:
			DeepUi.icon(top, "next", 16, DeepUi.MUTED).mouse_filter = Control.MOUSE_FILTER_PASS
		if used:
			card.self_modulate.a = 0.75
	home.enter(panel, 0.12)

static func _commissions(home: Control, parent: VBoxContainer) -> void:
	var panel := DeepUi.card(parent, DeepUi.LINE, 12)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(panel, 8)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "flag", "Commissions").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.stat(head, "flag", str(int(home.profile.get("records", {}).get("commissions", 0))), DeepUi.ACCENT, 12, "Commissions filled")
	DeepUi.wrap(box, "Bring home the stone a commission names, or hand over one you keep.", 12, DeepUi.DIM)
	var list: Array = home.profile.get("daily", {}).get("commissions", [])
	if list.is_empty():
		DeepUi.label(box, "No commissions today.", 13, DeepUi.DIM)
		DeepUi.spacer(box, false)
	for commission in list:
		_commission_row(home, box, commission)
	var price: int = DeepEconomy.reroll_price(home.profile)
	## Wrapped: unwrapped, the long free-swap line widened this column, and the case jumped once a swap shortened it.
	DeepUi.wrap(box, "Swapping one is free once a day, then %d gold and more each time." % int(DeepContent.constant("commission_reroll_gold", 10)) if price == 0 else "The next swap costs %d gold." % price, 12, DeepUi.DIM)
	home.enter(panel, 0.1)

static func _commission_row(home: Control, box: VBoxContainer, commission: Dictionary) -> void:
	var skill_key: String = str(commission.get("skill", ""))
	var skill: Dictionary = DeepContent.skill(skill_key)
	var hue: Color = DeepUi.color(str(skill.get("color", "WHITE")))
	var done: bool = bool(commission.get("done", false))
	var on_tray: Array = home.profile.get("tray", []).filter(func(s: Dictionary) -> bool: return DeepEconomy.meets(commission, s))
	var kept: Dictionary = DeepEconomy.vault_fill(home.profile, commission)
	var ready: bool = not done and (not on_tray.is_empty() or not kept.is_empty())
	## The three share the column's height, each read down its middle: the skill's emblem large
	## and what it asks under it, the way to fill it at the foot, and what it pays and the swap
	## in the top corners.
	var card := DeepUi.card(box, Color(DeepUi.GOOD if ready else hue, 0.5 if not done else 0.15), 10, Color(0.05, 0.07, 0.11, 0.9))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := DeepUi.vbox(card, 4)
	var middle := DeepUi.vbox(column, 4)
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var known: bool = home.profile.get("vault", {}).has(skill_key) or home.profile.get("seen", []).has(skill_key)
	var emblem := DeepUi.icon(middle, GemIcons.emblem(skill_key), 56, Color(hue, (0.95 if known else 0.45) * (1.0 if not done else 0.5)), str(skill.get("text", "")))
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var names := DeepUi.hbox(middle, 6)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.label(names, str(skill.get("name", skill_key)), 17, hue.lightened(0.25) if not done else DeepUi.DIM)
	if DeepProfile.favorites(home.profile).has(skill_key):
		DeepUi.icon(names, "star", 14, DeepUi.ACCENT_HI, "One of your favorites")
	var need: String = DeepEconomy.need_text(commission.get("need", {}))
	## Only the first letter goes up: capitalize() would title-case it into "Keen Cut Or Better".
	DeepUi.label(middle, "Any %s" % str(skill.get("name", skill_key)) if need.is_empty() else need.left(1).to_upper() + need.substr(1), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if done:
		## Paid sits at the foot where the button was.
		var paid := DeepUi.pill(column, "check", "Paid %d" % int(commission.get("paid", 0)), DeepUi.GOOD, 12)
		paid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_card_foot(column)
		return
	## The corners are laid over the card rather than above what it asks, so they cost the card
	## no height: the emblem sits clear of them between.
	var corners := DeepUi.hbox(card, 6)
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pays := DeepUi.stat(corners, "coin", "%d+" % int(commission.get("reward", 0)), DeepUi.ACCENT, 15, "Pays %d gold, or a quarter more than the stone would sell for if it is finer than that." % int(commission.get("reward", 0)))
	pays.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	DeepUi.spacer(corners).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var id: String = str(commission.get("id", ""))
	var price: int = DeepEconomy.reroll_price(home.profile)
	var reroll := _gold_button(corners, "reroll", "Free" if price == 0 else "", "" if price == 0 else str(price), func() -> void:
		if bool(DeepEconomy.reroll(home.profile, id).get("ok", false)):
			DeepAudio.play("ui_confirm", {"volume": 0.7})
			home.changed(["market_commissions"]), DeepUi.MUTED)
	reroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	reroll.disabled = int(home.profile.get("gold", 0)) < price
	reroll.tooltip_text = ("Swap it for another skill · %s" % ("free once a day" if price == 0 else "%d gold" % price)) if not reroll.disabled else "You have %d gold. A swap costs %d." % [int(home.profile.get("gold", 0)), price]
	if not on_tray.is_empty():
		var go := _gold_button(column, "", "On your tray", "+%d" % DeepEconomy.payout(commission, on_tray[0]), func() -> void:
			home._appraise_pick = str(on_tray[0].id)
			home._vault_view = "unappraised"
			home.open("vault", true), DeepUi.GOOD, on_tray[0])
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.tooltip_text = "Your %s on the tray meets it. Turn it in from the tray." % DeepUi.skill_name(on_tray[0])
	elif not kept.is_empty():
		var sure: bool = home._commission_sure == id
		var hand := _gold_button(column, "", "Sure? Give it up" if sure else "Turn in yours", "+%d" % DeepEconomy.payout(commission, kept), func() -> void:
			if not sure:
				home._commission_sure = id
				DeepAudio.play("ui_deny", {"volume": 0.5})
				if not home.redraw(["market_commissions"]):
					home._render()
				return
			if bool(DeepEconomy.turn_in_vault(home.profile, id).get("ok", false)):
				home._commission_sure = ""
				DeepAudio.play("sell")
				## The stone left the vault: the case's "yours" beside it may be gone too.
				home.changed(["market_case", "market_commissions"]), DeepUi.BAD if sure else DeepUi.GOOD, kept)
		hand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hand.tooltip_text = "The %s in your vault meets it. Handing it over takes it out of the vault and every loadout." % DeepUi.skill_name(kept)
	if ready:
		_card_foot(column)

static func _card_foot(column: VBoxContainer) -> void:
	## A little room under what sits at a commission's foot, off the card's bottom edge.
	var foot := Control.new()
	foot.custom_minimum_size.y = 4
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)

static func _gold_button(parent: Node, glyph: String, words: String, gold: String, callback: Callable, tint: Color, stone: Dictionary = {}) -> Button:
	## A button whose sum is read as gold: its mark (or the stone it hands over, which
	## right-clicks for the close look like any stone shown), its words, then the coin and the
	## sum. No sum, no coin.
	var b := DeepUi.button(parent, "", callback, 13)
	var row := DeepUi.hbox(b, 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not stone.is_empty():
		StoneCard.mini(row, stone, 30.0)
	elif not glyph.is_empty():
		DeepUi.icon(row, glyph, 17, tint).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not words.is_empty():
		DeepUi.label(row, words, 13, tint).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not gold.is_empty():
		DeepUi.price_chip(row, gold, 13)
	## The row is laid over the button rather than inside it (a Button lays nothing out), so
	## the button is told the row's size, and told again whenever it changes.
	var fit := func() -> void: b.custom_minimum_size = row.get_combined_minimum_size() + Vector2(24, 8)
	row.minimum_size_changed.connect(fit)
	fit.call()
	return b

# --- the Wheel and the Oven ---------------------------------------------------------------------------

static func _rework_page(home: Control, content: VBoxContainer, kind: String) -> void:
	var wheel: bool = kind == "cut"
	var head := _head(home, content, "The Wheel" if wheel else "The Oven", true)
	DeepUi.label(head, "Recut a stone from your vault. Its Cut always changes, better or worse." if wheel else "Fire a stone from your vault. Its Clarity always changes, and what is frozen inside is drawn again.", 14, DeepUi.MUTED)
	var used: bool = DeepEconomy.rework_used(home.profile, kind)
	if used:
		DeepUi.pill(head, "check", "Used today", DeepUi.MUTED, 12)
	var columns := DeepUi.hbox(content, 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var picker := DeepUi.card(columns, DeepUi.LINE, 12)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(picker, 8)
	var top := DeepUi.hbox(box, 8)
	DeepUi.section(top, "chest", "Your vault").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StoneBrowser.toolbar(home, top, "bench", {"compact": true, "rarity": false})
	var stones: Array = _held_in_place(home, kind, StoneBrowser.sorted(home, home.profile.get("vault", {}).values(), "bench"))
	var pager_row := DeepUi.hbox(box, 8)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	box.add_child(flow)
	if stones.is_empty():
		DeepUi.label(flow, "No kept stone matches.", 13, DeepUi.DIM)
	for stone in home.paged(pager_row, "bench_page", stones, PICK_PAGE):
		var skill: String = str(stone.get("skill", ""))
		var tile := StoneCard.tile(flow, stone, 70)
		if skill == home._rework_pick:
			var style: StyleBoxFlat = tile.get_theme_stylebox("panel").duplicate()
			style.border_color = DeepUi.ACCENT
			style.set_border_width_all(2)
			tile.add_theme_stylebox_override("panel", style)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DeepUi.juice(tile, 1.06)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_tap")
				## Another stone picked: the last result has been read.
				if skill != home._rework_pick:
					home._rework_done = {}
				home._rework_pick = skill
				home._render())
	home.enter(picker, 0.05)
	var side := DeepUi.card(columns, Color(DeepUi.ACCENT, 0.4), 16)
	side.custom_minimum_size.x = 460
	var side_box := DeepUi.vbox(side, 10)
	var stone: Dictionary = DeepProfile.owned(home.profile, home._rework_pick)
	## The last result on this page, if it is still the one being looked at; a stone that broke
	## leaves nothing picked, and its result stays until another is.
	var done: Dictionary = home._rework_done
	var held: bool = used and str(done.get("kind", "")) == kind and (str(done.get("skill", "")) == home._rework_pick
		or (bool(done.get("broke", false)) and home._rework_pick.is_empty()))
	if stone.is_empty() and held and bool(done.broke):
		_rework_head(side_box, done.before, kind)
		var lost := Rework.new(done.before, kind, REWORK_EDGE)
		lost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lost.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side_box.add_child(lost)
		lost.settle(int(done.now), true)
		DeepUi.label(side_box, "Choose another stone from your vault.", 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.gap(side_box, 8)
		home.enter(side, 0.1)
		return
	if stone.is_empty():
		DeepUi.section(side_box, "cut" if wheel else "flame", "On the wheel" if wheel else "In the oven")
		DeepUi.spacer(side_box, false)
		DeepUi.label(side_box, "Choose a stone from your vault.", 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		## What the work is, before anything is chosen: what changes, what it costs, the risk.
		var terms := DeepUi.vbox(side_box, 8)
		terms.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.gap(terms, 6)
		DeepUi.stat(terms, "cut" if wheel else "flame", "Its Cut always moves, up or down. Nothing else changes." if wheel else "Its Clarity always moves, and what is frozen inside is drawn again.", DeepUi.PAPER, 13)
		var share: float = float(DeepContent.constant("rework_price_mult", 0.5))
		DeepUi.stat(terms, "coin", "Costs %s the stone's worth, %d gold at the least." % ["half" if is_equal_approx(share, 0.5) else "%d%% of" % roundi(share * 100.0), int(DeepContent.constant("rework_gold_min", 25))], DeepUi.ACCENT, 13)
		DeepUi.stat(terms, "split_shield", "1 in %d stones break %s." % [roundi(100.0 / maxf(0.01, DeepEconomy.rework_break_pct())), "on the wheel" if wheel else "in the oven"], DeepUi.BAD, 13)
		DeepUi.stat(terms, "calendar", "Once a day.", DeepUi.MUTED, 13)
		DeepUi.spacer(side_box, false)
		home.enter(side, 0.1)
		return
	_rework_head(side_box, stone, kind)
	## After a rework the ladder stays where it landed, read from the rung it started on, with
	## the stone as it came out standing over it, and under it what that did to its worth (and
	## in the Oven, what is frozen inside it now).
	var reveal := Rework.new(done.before if held else stone, kind, REWORK_EDGE)
	reveal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reveal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(reveal)
	if held:
		reveal.settle(int(done.now), false)
		var picture: Variant = reveal.get("_picture")
		if picture is Control:
			(picture as Control).call("configure", stone)
		_rework_result(side_box, done.before, stone, kind)
	DeepUi.section(side_box, "scales", "What it could come out as", DeepUi.MUTED, 12)
	var names: Array = DeepContent.cuts() if wheel else DeepContent.clarities()
	var parts: Array = []
	for entry in DeepEconomy.rework_odds(stone, kind):
		if str(entry[0]) == "break":
			parts.append({"label": "Breaks", "share": float(entry[1]), "color": DeepUi.BAD})
		else:
			var rung: int = int(entry[0])
			parts.append({"label": str(names[rung].get("name", "")), "share": float(entry[1]), "color": _cut_tone(rung) if wheel else _clarity_tone(rung)})
	side_box.add_child(HomeParts.OddsBar.new(parts))
	var risk := DeepUi.stat(side_box, "split_shield", "1 in 25 stones break %s." % ("on the wheel" if wheel else "in the oven"), DeepUi.BAD, 13)
	risk.alignment = BoxContainer.ALIGNMENT_CENTER
	var refusal: String = DeepEconomy.rework_refusal(home.profile, home._rework_pick, kind)
	var price: int = DeepEconomy.rework_price(stone)
	## The button, reached from inside its own press, so it can go dark while the wheel turns.
	var pressed: Array = []
	var go := DeepUi.primary(side_box, "cut" if wheel else "flame", ("Recut %s" if wheel else "Fire %s") % DeepUi.skill_name(stone), func() -> void:
		var skill: String = home._rework_pick
		## The stone as it goes in, and where its tile stands: the rework changes it in place.
		var before: Dictionary = DeepProfile.owned(home.profile, skill).duplicate(true)
		var at: int = stones.map(func(s: Dictionary) -> String: return str(s.get("skill", ""))).find(skill)
		var result: Dictionary = DeepEconomy.rework(home.profile, skill, kind)
		if not bool(result.get("ok", false)):
			return
		if not pressed.is_empty() and is_instance_valid(pressed[0]):
			(pressed[0] as Button).disabled = true
		home.touch()
		home._rework_done = {"kind": kind, "skill": skill, "before": before, "now": int(result.now), "broke": bool(result.broke)}
		home._rework_hold = {"kind": kind, "skill": skill, "at": at, "sort": _sort_mark(home)} if at >= 0 and not bool(result.broke) else {}
		if bool(result.broke):
			home._rework_pick = ""
		else:
			## Its new photograph taken while the ladder spins, for the page drawn after it lands.
			Thumbs.request(Thumbs.gem_key(result.stone), "gem", {"stone": result.stone}, func(_texture: Texture2D) -> void: pass)
		## Told a moment after the reveal, or as soon as the page is left before it is over.
		var settle: Callable = home.when_done(reveal, func() -> void: home.profile_changed.emit())
		reveal.finished.connect(func() -> void:
			if not bool(result.broke) and is_instance_valid(side_box):
				## What the landing did to its worth (and what is inside it), under the ladder.
				var said: Control = _rework_result(side_box, before, result.stone, kind)
				side_box.move_child(said, reveal.get_index() + 1)
				DeepUi.pop_in(said, 0.05)
			home.get_tree().create_timer(1.6).timeout.connect(settle), CONNECT_ONE_SHOT)
		reveal.play(int(result.now), bool(result.broke)), 17, DeepUi.INFO)
	DeepUi.priced(go, str(price))
	pressed.append(go)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(300, 50)
	go.disabled = not refusal.is_empty()
	go.tooltip_text = refusal if not refusal.is_empty() else "The price follows the stone's worth."
	DeepUi.label(side_box, refusal if not refusal.is_empty() else "The price follows the stone's worth.", 12, DeepUi.BAD if not refusal.is_empty() else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	home.enter(side, 0.1)

static func _rework_head(side_box: VBoxContainer, stone: Dictionary, kind: String) -> void:
	var wheel: bool = kind == "cut"
	DeepUi.section(side_box, "cut" if wheel else "flame", "On the wheel" if wheel else "In the oven")
	## The stone's name over it, and the stone standing in all the room the column has left, so
	## a heavy one hangs clear of the name above and the ladder below.
	DeepUi.title(side_box, DeepUi.skill_name(stone), 24, DeepUi.color(DeepStone.color(stone)).lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	## Under the name, what the work leaves alone: its carat, and the Clarity on the Wheel or
	## the Cut in the Oven, each in the color its odds are drawn in.
	var kept_marks := DeepUi.hbox(side_box, 16)
	kept_marks.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.stat(kept_marks, "carat", "%d ct" % int(stone.get("carat", 1)), DeepUi.ACCENT, 14, GemIcons.hint("carat"))
	if wheel:
		var clarity: int = int(stone.get("clarity", DeepContent.clear_index()))
		DeepUi.stat(kept_marks, "clarity", DeepContent.clarity_name(clarity), _clarity_tone(clarity), 14, GemIcons.hint("clarity"))
	else:
		var cut: int = int(stone.get("cut", 0))
		DeepUi.stat(kept_marks, "cut", DeepContent.cut_name(cut), _cut_tone(cut), 14, GemIcons.hint("cut"))

static func _rework_result(parent: Node, before: Dictionary, after: Dictionary, kind: String) -> Control:
	## Under the ladder's "Cut: Poor → Keen", what else the work changed: what the stone is worth
	## now, and in the Oven each thing frozen inside it now, by name.
	var box := DeepUi.vbox(parent, 6)
	var was: int = DeepStone.value(before)
	var now: int = DeepStone.value(after)
	var tone: Color = DeepUi.GOOD if now > was else (DeepUi.BAD if now < was else DeepUi.MUTED)
	var worth := DeepUi.stat(box, "coin", "Worth %d → %d" % [was, now], tone, 15, "What it sells for, before and after")
	worth.alignment = BoxContainer.ALIGNMENT_CENTER
	if kind == "clarity":
		var inside := DeepUi.hbox(box, 6)
		inside.alignment = BoxContainer.ALIGNMENT_CENTER
		var found: Array = after.get("inclusions", [])
		if found.is_empty():
			DeepUi.pill(inside, "prism", "Nothing frozen inside", DeepUi.MUTED, 12)
		for key in found:
			var capsule := DeepUi.pill(inside, "prism", str(DeepContent.inclusion(str(key)).get("name", key)), INCLUSION_TONE, 12)
			var named: String = str(key)
			Tips.attach(capsule, func() -> Control: return _inclusion_plate(named))
	return box

static func _sort_mark(home: Control) -> String:
	## The picker's sort and filters as they stand, so a held place lasts only while they do.
	var s: Dictionary = StoneBrowser.settings(home, "bench")
	return var_to_str([s.get("sort", ""), s.get("desc", true), s.get("colors", []), s.get("rarity", ""), s.get("query", "")])

static func _held_in_place(home: Control, kind: String, stones: Array) -> Array:
	## The picker's stones, with the one just reworked kept where its tile stood before: its new
	## grade would otherwise move it across the page under the player's eye. Only on the page
	## it was reworked on, and only while the sort and the filters are as they were.
	var hold: Dictionary = home._rework_hold
	if str(hold.get("kind", "")) != kind or str(hold.get("sort", "")) != _sort_mark(home):
		return stones
	var skill: String = str(hold.get("skill", ""))
	var from: int = stones.map(func(s: Dictionary) -> String: return str(s.get("skill", ""))).find(skill)
	if from < 0:
		return stones
	var out: Array = stones.duplicate()
	var stone: Dictionary = out.pop_at(from)
	out.insert(clampi(int(hold.get("at", from)), 0, out.size()), stone)
	return out

static func _cut_tone(rung: int) -> Color:
	## Each Cut its own color on the Wheel's odds: from the accent's gold at the worst to green
	## at the best.
	return DeepUi.ACCENT.lerp(DeepUi.GOOD, float(rung) / float(maxi(1, DeepContent.cuts().size() - 1)))

static func _clarity_tone(rung: int) -> Color:
	## Each Clarity its own color on the Oven's odds: Clear a plain grey, the rungs below it a
	## deeper violet the more is frozen inside, the rungs above it a paler ice the purer.
	var clear: int = DeepContent.clear_index()
	if rung == clear:
		return Color("a7adb9")
	if rung < clear:
		return Color("d6c0ff").lerp(Color("7b42e6"), float(clear - 1 - rung) / float(maxi(1, clear - 1)))
	var top: int = DeepContent.clarities().size() - 1
	return Color("5fbdf5").lerp(Color("e4faff"), float(rung - clear - 1) / float(maxi(1, top - clear - 1)))

# --- the trade-up contract ---------------------------------------------------------------------------

static func _contract_page(home: Control, content: VBoxContainer) -> void:
	## The contract bench: five stones of one grade in, one of the next grade out. The bench on
	## the left with its five places running down to the one they make and what that one could
	## be; the stones it could take on the right.
	var head := _head(home, content, "Trade-up contract", true)
	DeepUi.stat(head, "contract", "%s signed" % DeepUi.plural(int(home.profile.get("records", {}).get("contracts", 0)), "contract"), DeepUi.ACCENT, 13)
	if DeepEconomy.contract_signed_today(home.profile):
		DeepUi.pill(head, "check", "Signed today", DeepUi.MUTED, 12)
	home._contract = home._contract.filter(func(ref: Variant) -> bool: return not DeepEconomy.contract_input(home.profile, str(ref)).is_empty())
	var preview: Dictionary = DeepEconomy.contract_preview(home.profile, home._contract)
	if not bool(preview.ok):
		home._contract = []
		preview = DeepEconomy.contract_preview(home.profile, home._contract)
	var columns := DeepUi.hbox(content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tier: String = str(preview.get("tier", ""))
	var next: String = str(preview.get("next", ""))
	var tone: Color = DeepUi.tier_color(next) if not next.is_empty() else DeepUi.ACCENT
	var bench := DeepUi.card(columns, Color(tone, 0.45), 16)
	bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(bench, 10)
	var promise := DeepUi.hbox(box, 14)
	promise.alignment = BoxContainer.ALIGNMENT_CENTER
	if tier.is_empty():
		DeepUi.pill(promise, "gem", "Five of one grade", DeepUi.MUTED, 16)
		DeepUi.icon(promise, "next", 26, DeepUi.DIM)
		DeepUi.pill(promise, "star", "One of the next", DeepUi.MUTED, 16)
	else:
		DeepUi.pill(promise, "gem", "5 × %s" % str(DeepStone.TIER_NAMES.get(tier, tier)), DeepUi.tier_color(tier), 16)
		DeepUi.icon(promise, "next", 26, tone)
		DeepUi.pill(promise, "star", str(DeepStone.TIER_NAMES.get(next, next)), tone, 16)
	DeepUi.wrap(box, "Its color is drawn from theirs, it weighs their average, and it is cut from the deepest of their mines' rock, with a grade one step up.",
		13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER).custom_minimum_size.x = 640
	var slots := DeepUi.hbox(box, 14)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	var stones: Array = preview.get("stones", [])
	for index in range(DeepEconomy.contract_size()):
		_contract_slot(home, slots, index, stones[index] if index < stones.size() else {})
	var signable: bool = bool(preview.get("ready", false))
	var flow := HomeParts.Funnel.new(stones.size(), DeepEconomy.contract_size(), DeepUi.tier_color(tier) if not tier.is_empty() else DeepUi.DIM, signable, CONTRACT_SLOT.x + 14.0)
	flow.custom_minimum_size = Vector2(0, 48)
	box.add_child(flow)
	DeepUi.center(box).add_child(HomeParts.Outcome.new(tone if not next.is_empty() else DeepUi.DIM, float(stones.size()) / float(DeepEconomy.contract_size()), signable))
	_contract_forecast(home, box, preview)
	DeepUi.spacer(box, false)
	if not preview.get("vault", []).is_empty():
		var names: Array = preview.vault.map(func(k: Variant) -> String: return str(DeepContent.skill(str(k)).get("name", k)))
		DeepUi.stat(box, "chest", "From your vault: %s. Signed, %s no longer kept." % [", ".join(names), "it is" if names.size() == 1 else "they are"], DeepUi.BAD, 13).alignment = BoxContainer.ALIGNMENT_CENTER
	var sign_row := DeepUi.hbox(box, 12)
	sign_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var giving_up: bool = not preview.get("vault", []).is_empty()
	var words: String = "Sign it, vault stones and all" if signable and giving_up and home._contract_sure else "Sign the contract"
	var sign := DeepUi.primary(sign_row, "contract", words, func() -> void:
		if giving_up and not home._contract_sure:
			home._contract_sure = true
			DeepAudio.play("ui_deny", {"volume": 0.6})
			home._render()
			return
		_sign_contract(home), 17, DeepUi.BAD if giving_up and home._contract_sure else DeepUi.coin_safe(tone))
	if signable:
		DeepUi.priced(sign, str(int(preview.fee)))
	sign.custom_minimum_size = Vector2(320, 50)
	DeepUi.voice(sign, "ui_tap" if giving_up and not home._contract_sure else "contract_seal")
	sign.disabled = not signable
	if signable:
		DeepUi.breathe(sign, 0.82, 1.8)
	var reason: String = str(preview.get("reason", ""))
	if not reason.is_empty():
		DeepUi.label(box, reason, 13, DeepUi.BAD if not bool(preview.get("feasible", true)) else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	elif giving_up and not home._contract_sure:
		DeepUi.label(box, "Signing gives up stones from your vault: it asks twice.", 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	home.enter(bench, 0.05)
	_contract_picker(home, columns, preview)

static func _contract_slot(home: Control, parent: Node, index: int, stone: Dictionary) -> void:
	var empty: bool = stone.is_empty()
	var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if not empty else DeepUi.LINE
	var slot := DeepUi.card(parent, Color(tone, 0.6) if not empty else DeepUi.LINE, 10, Color(0.05, 0.06, 0.085, 0.9) if not empty else Color(0.03, 0.035, 0.05, 0.6))
	slot.custom_minimum_size = CONTRACT_SLOT
	var box := DeepUi.vbox(slot, 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(96, 96)
	stand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stand)
	var ring := BattleScreen.SocketRing.new("ANY", empty)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stand.add_child(ring)
	if empty:
		var plus := DeepUi.icon(stand, "gem", 34, Color(DeepUi.DIM, 0.6))
		plus.position = Vector2(31, 31)
		DeepUi.label(box, "Stone %d" % (index + 1), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, "pick from the right", 12, Color(DeepUi.DIM, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		return
	var thumb := StoneCard.mini(stand, stone, 80, DeepStone.name(stone))
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	thumb.mouse_filter = Control.MOUSE_FILTER_PASS
	DeepUi.fit_label(box, DeepUi.skill_name(stone), 14, DeepUi.PAPER, 130)
	var marks := DeepUi.hbox(box, 6)
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	DeepUi.stat(marks, "carat", str(int(stone.get("carat", 1))), DeepUi.ACCENT, 12, "%d carats" % int(stone.get("carat", 1)))
	var ref: String = str(home._contract[index]) if index < home._contract.size() else ""
	if ref.begins_with("v:"):
		DeepUi.icon(marks, "chest", 15, DeepUi.BAD, "From your vault")
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.tooltip_text = "%s\nClick to take it back off the bench" % DeepStone.name(stone)
	DeepUi.juice(slot, 1.04)
	slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			home._contract.erase(ref)
			home._contract_sure = false
			DeepAudio.play("die_drop", {"volume": 0.7})
			home._render.call_deferred())

static func _contract_forecast(home: Control, box: VBoxContainer, preview: Dictionary) -> void:
	var line := DeepUi.hbox(box, 22)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	var next: String = str(preview.get("next", ""))
	if next.is_empty():
		DeepUi.label(line, "Five Rough make a Fine, five Fine a Precious, five Precious an Exquisite, and five Exquisite a Peerless.", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	DeepUi.stat(line, "star", "A %s stone" % str(DeepStone.TIER_NAMES.get(next, next)), DeepUi.tier_color(next), 15, "Its Cut, Clarity and inclusions are rolled until its grade lands in this tier.")
	DeepUi.stat(line, "carat", "%d carats" % int(preview.get("carat", 1)), DeepUi.ACCENT, 15, "The average of the stones on the bench, never past the cap of the rock it is cut from.")
	var mine_key: String = str(preview.get("mine", ""))
	var palette: String = str(DeepContent.mine(mine_key).get("palette", ""))
	DeepUi.stat(line, "pick", "%s's rock" % DeepContent.mine_name(mine_key), Color(palette).lightened(0.2) if not palette.is_empty() else DeepUi.PAPER, 15,
		"The deepest mine any of the stones came from. The new one's skill is one that rock can hold.")
	var row := DeepUi.hbox(box, 26)
	var colors_box := DeepUi.vbox(row, 6)
	colors_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colors_box.size_flags_stretch_ratio = 0.8
	DeepUi.section(colors_box, "prism", "Its color", DeepUi.MUTED, 12)
	var parts: Array = []
	var colors: Dictionary = preview.get("colors", {})
	for key in DeepContent.SKILL_COLORS:
		if float(colors.get(key, 0.0)) > 0.0:
			parts.append({"label": str(DeepContent.color(key).get("name", key)), "share": float(colors[key]), "color": DeepUi.color(key)})
	if parts.is_empty():
		DeepUi.wrap(colors_box, "No color can make the grade at this weight.", 13, DeepUi.BAD)
	else:
		colors_box.add_child(HomeParts.OddsBar.new(parts))
	var can := DeepUi.vbox(row, 6)
	can.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.section(can, "gem", "It could become", DeepUi.MUTED, 12)
	var marks: Array = []
	for entry in DeepEconomy.contract_odds(preview):
		var key: String = str(entry[0])
		var def: Dictionary = DeepContent.skill(key)
		var known: bool = home.profile.get("vault", {}).has(key) or home.profile.get("seen", []).has(key)
		marks.append({"glyph": GemIcons.emblem(key), "color": DeepUi.color(str(def.get("color", ""))), "known": known, "name": str(def.get("name", key)),
			"tip": "%s · %s · %s%s" % [str(def.get("name", key)), str(def.get("rarity", "COMMON")).capitalize(), Geode.percent(float(entry[1])), "" if known else "\nNever found yet"]})
	if marks.is_empty():
		DeepUi.label(can, "Nothing, at this weight.", 13, DeepUi.DIM)
	else:
		can.add_child(HomeParts.MarkRows.new(marks))

static func _contract_picker(home: Control, columns: Node, preview: Dictionary) -> void:
	## The stones that could go on the bench, a page at a time: the tray's read stones and the
	## vault's. Once the first is on, only stones of its grade can follow.
	var picker := DeepUi.card(columns, DeepUi.LINE, 14)
	picker.custom_minimum_size.x = 520
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(picker, 10)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "chest", "Your stones").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [["all", "All"], ["tray", "Tray"], ["vault", "Vault"]]:
		var key: String = str(entry[0])
		DeepUi.tab_button(head, {"all": "gem", "tray": "bag", "vault": "chest"}[key], str(entry[1]), home._contract_from == key, func() -> void:
			home._contract_from = key
			home._pages["contract"] = 0
			home._render(), 13)
	var everything: Array = DeepEconomy.contract_stones(home.profile)
	var listed: Array = everything.filter(func(e: Dictionary) -> bool:
		return home._contract_from == "all" or (home._contract_from == "vault") == bool(e.vault))
	var tier: String = str(preview.get("tier", ""))
	var hint_row := DeepUi.hbox(box, 8)
	DeepUi.label(hint_row, "Pick five stones of one grade; the first sets the grade." if tier.is_empty() else "Only %s stones can join these." % str(DeepStone.TIER_NAMES.get(tier, tier)), 13, DeepUi.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Fill from cheapest: the five lowest-worth stones of the grade on the bench (or, empty,
	## of the lowest grade that has five).
	var fill_tier: String = tier
	if fill_tier.is_empty():
		for candidate in DeepEconomy.CONTRACT_TIERS:
			if DeepEconomy.cheapest_contract(home.profile, str(candidate)).size() >= DeepEconomy.contract_size():
				fill_tier = str(candidate)
				break
	var fill := DeepUi.icon_button(hint_row, "spark", "Fill from cheapest", func() -> void:
		home._contract = DeepEconomy.cheapest_contract(home.profile, fill_tier)
		home._contract_sure = false
		DeepAudio.play("die_pick", {"volume": 0.8})
		home._render(), 13, DeepUi.ACCENT)
	fill.disabled = fill_tier.is_empty() or DeepEconomy.cheapest_contract(home.profile, fill_tier).size() < DeepEconomy.contract_size()
	fill.tooltip_text = "Puts in the five lowest-worth %s stones you have." % str(DeepStone.TIER_NAMES.get(fill_tier, "matching")).to_lower() if not fill.disabled else "There are not five stones of one grade to put in."
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	if listed.is_empty():
		DeepUi.label(grid, "Nothing here can go into a contract yet.", 13, DeepUi.DIM)
	var full: bool = home._contract.size() >= DeepEconomy.contract_size()
	## Whose sockets each vault stone is set in: signing one away empties those sockets too,
	## and the chest mark every vault tile wears does not say so.
	var wearing: Dictionary = StoneBrowser._wearers(home)
	for entry in home.paged(box, "contract", listed, CONTRACT_PAGE):
		var stone: Dictionary = entry.stone
		var ref: String = str(entry.ref)
		var placed: bool = home._contract.has(ref)
		var fits: bool = tier.is_empty() or str(DeepStone.grade(stone).tier) == tier
		var tile := StoneCard.tile(grid, stone, 72)
		if bool(entry.vault):
			home.tile_mark(tile, "chest", DeepUi.INFO, "In your vault: put in a contract, its skill is no longer kept")
		if bool(entry.vault) and wearing.has(ref.substr(2)):
			var who: Array = wearing[ref.substr(2)].map(func(k: Variant) -> String: return str(DeepContent.character(str(k)).get("name", k)))
			home.tile_mark(tile, "person", DeepUi.BAD, "In %s's sockets: signed away, it leaves them" % " and ".join(who))
		if placed:
			home.tile_mark(tile, "check", DeepUi.GOOD, "On the bench")
			tile.modulate = Color(1, 1, 1, 0.45)
			continue
		if not fits or full:
			tile.modulate = Color(1, 1, 1, 0.28)
			tile.tooltip_text = ("Not %s: a contract takes stones of one grade" % str(DeepStone.TIER_NAMES.get(tier, tier))) if not fits else "The bench is full"
			continue
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		DeepUi.juice(tile, 1.06)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				home._contract.append(ref)
				home._contract_sure = false
				DeepAudio.play("die_pick", {"volume": 0.7})
				home._render.call_deferred())
	DeepUi.spacer(box, false)
	DeepUi.wrap(box, "Raw stones need reading first. Birthstones, opals, fragile stones and Peerless stones cannot go in.", 12, DeepUi.DIM)
	if not home._contract.is_empty():
		var clear := DeepUi.icon_button(box, "cross_out", "Clear the bench", func() -> void:
			home._contract = []
			home._contract_sure = false
			home._render(), 13, DeepUi.MUTED)
		clear.size_flags_horizontal = Control.SIZE_SHRINK_END
	home.enter(picker, 0.1)

static func _sign_contract(home: Control) -> void:
	## Signs the bench's contract: the fee and the stones are gone, the new stone is on the
	## tray, and the bench plays the five going in and the one coming out.
	var signed: Dictionary = DeepEconomy.sign_contract(home.profile, home._contract)
	if not bool(signed.get("ok", false)):
		return
	home._contract = []
	home._contract_sure = false
	home._market_view = "main"
	var made: Dictionary = signed.stone
	home.touch()
	Geode.fuse(signed.given, made, {"actions": found_actions(home, made), "owned": DeepProfile.owned(home.profile, str(made.get("skill", "")))}, func() -> void: home.profile_changed.emit())
	if DeepUi.headless():
		home.profile_changed.emit()
