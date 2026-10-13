extends RefCounted
## The Market: everything bought or paid for. Today's Geode and the week's down the left; the
## case of cut and read stones in the middle; the day's commissions and the bench (the Wheel,
## the Oven and the trade-up contract, each once a day) down the right. Restock replaces
## today's Geode and the case once a day, for gold. The Wheel, the Oven and the contract each
## open a page of their own; Escape or the way back returns to the counter.

const HomeParts = preload("res://view/home/home_parts.gd")
const StoneBrowser = preload("res://view/home/stone_browser.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Geode = preload("res://view/gems/geode.gd")
const Rework = preload("res://view/gems/rework.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

## How many vault stones the Wheel's and the Oven's picker shows a page: three rows.
const PICK_PAGE: int = 33
## How many stones the contract bench's picker shows a page: four rows of five.
const CONTRACT_PAGE: int = 20
## The size of a place on the contract bench.
const CONTRACT_SLOT := Vector2(150, 176)

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
	var head := _head(home, content, "The market", false)
	var left: int = DeepEconomy.seconds_to_tomorrow()
	DeepUi.stat(head, "hourglass", "New stock in %dh %02dm" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 13, "Today's Geode, the case and the commissions turn over at midnight UTC.")
	var price: int = DeepEconomy.restock_price()
	var done: bool = DeepEconomy.restocked_today(home.profile)
	var restock := DeepUi.icon_button(head, "reroll", "Restocked today" if done else "Restock now · %d" % price, func() -> void:
		if bool(DeepEconomy.restock(home.profile).get("ok", false)):
			DeepAudio.play("buy")
			home.profile_changed.emit(), 13, DeepUi.ACCENT)
	restock.disabled = done or int(home.profile.get("gold", 0)) < price
	restock.tooltip_text = "Once a day: a new Geode of the day and a new case of cut stones. The week's Geode and the commissions stay." if not done else "The market can be restocked once a day."
	var columns := DeepUi.hbox(content, 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_geodes(home, columns)
	var middle := DeepUi.vbox(columns, 14)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_case(home, middle)
	var right := DeepUi.vbox(columns, 14)
	right.custom_minimum_size.x = 340
	_commissions(home, right)
	_bench(home, right)
	if not home._odds_open.is_empty():
		_odds_popover(home)

static func _wanted_in(home: Control, skills: Array) -> bool:
	var wanted: Array = DeepProfile.wanted(home.profile)
	return skills.any(func(k: Variant) -> bool: return wanted.has(str(k)))

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
	home.enter(panel, 0.05)

static func _geode_card(home: Control, parent: Node, geode: Dictionary) -> void:
	var weekly: bool = bool(geode.get("weekly", false))
	var bought: bool = bool(geode.get("bought", false))
	var tone: Color = Geode.theme_tone(geode)
	var card := DeepUi.card(parent, Color(DeepUi.ACCENT if weekly else tone, 0.55 if not bought else 0.2), 10, DeepUi.GLASS)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(card, 6)
	var tag := DeepUi.hbox(box, 6)
	var kind: String = ("This week's Geode" if weekly else "Today's Geode")
	DeepUi.heading(tag, kind, 11, DeepUi.ACCENT if weekly else tone).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if weekly:
		DeepUi.label(tag, DeepUi.plural(DeepEconomy.featured_days_left(DeepEconomy.today()), "day") + " left", 11, DeepUi.DIM)
	else:
		DeepUi.label(tag, "one color" if str(geode.get("kind", "")) == "color" else "one mine", 11, DeepUi.DIM)
	var art := Geode.Art.new(geode, tone)
	art.custom_minimum_size = Vector2(0, 110)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.open = bought
	box.add_child(art)
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
		DeepUi.pill(facts, "cut", "Fine cut or better", DeepUi.INFO, 11)
	if _wanted_in(home, DeepEconomy.geode_pool(geode)):
		DeepUi.pill(facts, "star", "wanted", DeepUi.ACCENT_HI, 11, "It can hold a skill you starred in the vault.")
	var foot := DeepUi.hbox(box, 6)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var id: String = str(geode.get("id", ""))
	var look := DeepUi.icon_button(foot, "eye", "Odds", func() -> void:
		home._odds_open = "" if home._odds_open == id else id
		DeepAudio.play("ui_open", {"volume": 0.6})
		home._render(), 12, DeepUi.MUTED)
	look.tooltip_text = "What it can hold, and how likely each thing is"
	if bought:
		var held: Dictionary = geode.get("stone", {}).duplicate(true)
		held.appraised = true
		StoneCard.mini(foot, held, 32)
		DeepUi.label(foot, "Opened", 12, DeepUi.DIM)
		return
	var price: int = int(geode.get("price", 0))
	var crack := DeepUi.primary(foot, "hammer", "Crack it · %d" % price, func() -> void: crack_geode(home, geode), 14)
	DeepUi.voice(crack, "geode_crack")
	crack.disabled = int(home.profile.get("gold", 0)) < price
	crack.tooltip_text = "Buys it and cracks it open, three blows." if not crack.disabled else "You have %d gold. This Geode costs %d." % [int(home.profile.get("gold", 0)), price]
	crack.mouse_entered.connect(func() -> void:
		if not crack.disabled:
			art.create_tween().tween_property(art, "hover", 1.0, 0.2))
	crack.mouse_exited.connect(func() -> void: art.create_tween().tween_property(art, "hover", 0.0, 0.3))

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

static func _odds_popover(home: Control) -> void:
	## A Geode's odds in full: the share of each rarity, every skill it can hold, the grades.
	var geode: Dictionary = {}
	for candidate in DeepEconomy.shelf(home.profile):
		if str(candidate.get("id", "")) == home._odds_open:
			geode = candidate
	if geode.is_empty():
		return
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			home._odds_open = ""
			home._render())
	home._overlay.add_child(catcher)
	var card := DeepUi.card(home._overlay, Color(Geode.theme_tone(geode), 0.6), 18, Color(DeepUi.INK, 0.97))
	card.custom_minimum_size.x = 520
	card.position = Vector2(340, 150)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := DeepUi.vbox(card, 10)
	DeepUi.title(box, Geode.geode_name(geode), 22, Geode.theme_tone(geode).lightened(0.2))
	var odds: Dictionary = DeepEconomy.geode_odds(geode)
	DeepUi.section(box, "gem", "What it can hold", DeepUi.MUTED, 12)
	var rarity_parts: Array = []
	var shares: Dictionary = Geode.rarity_shares(geode)
	for rarity in Geode.RARITIES:
		if float(shares.get(rarity, 0.0)) > 0.0:
			rarity_parts.append({"label": "Opal" if rarity == "MYTHIC" else rarity.capitalize(), "share": float(shares[rarity]), "color": Geode.rarity_tone(rarity), "rainbow": rarity == "MYTHIC"})
	box.add_child(HomeParts.OddsBar.new(rarity_parts))
	var marks: Array = []
	var wanted: Array = DeepProfile.wanted(home.profile)
	for entry in odds.get("skills", []):
		var key: String = str(entry[0])
		var def: Dictionary = DeepContent.skill(key)
		var known: bool = home.profile.get("vault", {}).has(key) or home.profile.get("seen", []).has(key)
		marks.append({"glyph": GemIcons.emblem(key), "color": DeepUi.color(str(def.get("color", ""))), "known": known, "name": str(def.get("name", key)),
			"tip": "%s · %s · %s%s%s" % [str(def.get("name", key)), str(def.get("rarity", "COMMON")).capitalize(), Geode.percent(float(entry[1])), "" if known else "\nNever found yet", "\nWanted" if wanted.has(key) else ""]})
	box.add_child(HomeParts.MarkRows.new(marks))
	DeepUi.section(box, "star", "How its stones grade", DeepUi.MUTED, 12)
	var tier_parts: Array = []
	for tier in DeepStone.TIERS:
		var share: float = float(odds.get("tiers", {}).get(tier, 0.0))
		if share > 0.0:
			tier_parts.append({"label": str(DeepStone.TIER_NAMES.get(tier, tier)), "share": share, "color": DeepUi.tier_color(tier)})
	box.add_child(HomeParts.OddsBar.new(tier_parts))
	var carats: Array = odds.get("carat", [1, 1])
	DeepUi.label(box, "%d to %d carats, cut and cleared with more luck than the rock gives, %s chance of an opal." % [int(carats[0]), int(carats[1]), Geode.percent(float(odds.get("opal", 0.0)))], 12, DeepUi.MUTED)
	DeepUi.pop_in(card, 0.0, 0.96, 0.2)

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
	var wanted: Array = DeepProfile.wanted(home.profile)
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
		var lamp := HomeParts.Showcase.new(stone, 270.0, 0.92)
		picture.add_child(lamp)
		if sold:
			lamp.modulate = Color(1, 1, 1, 0.35)
		var names := DeepUi.hbox(column, 6)
		names.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.label(names, DeepUi.skill_name(stone), 16, DeepUi.color(DeepStone.color(stone)).lightened(0.2) if not sold else DeepUi.DIM)
		DeepUi.label(names, str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), 12, DeepUi.tier_color(str(grade.tier)))
		if wanted.has(skill):
			DeepUi.icon(names, "star", 14, DeepUi.ACCENT_HI, "Wanted")
		DeepUi.label(column, "%d ct · %s · %s" % [int(stone.get("carat", 1)), DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.clarity_name(int(stone.get("clarity", 0)))], 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		## What it does, so a stone can be bought without leaving the counter to look it up.
		var rules := DeepUi.panel(column, Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.07), 6, 8)
		var rule_box := DeepUi.vbox(rules, 6)
		var trigger: Dictionary = DeepStone.skill_of(stone).get("trigger", {"kind": "always"})
		var need := DeepUi.center(rule_box)
		DiceIcons.build(need, DeepPatterns.describe(trigger, int(DeepStone.effective(stone, {}).cut_step)), 18, DeepUi.PAPER)
		DeepUi.effect_text(rule_box, DeepStone.text(stone, {}), 12, DeepUi.PAPER if not sold else DeepUi.DIM)
		StoneCard.carat_lines(rule_box, stone, {}, 11)
		for key in stone.get("inclusions", []):
			var inclusion: Dictionary = DeepContent.inclusion(str(key))
			DeepUi.wrap(rule_box, "%s: %s" % [str(inclusion.get("name", key)), str(inclusion.get("text", ""))], 11, Color("c58bff"))
		DeepUi.spacer(column, false)
		_yours_beside(column, stone, own)
		var id: String = str(entry.get("id", ""))
		if sold:
			DeepUi.label(column, "Sold", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var buy := DeepUi.icon_button(column, "coin", "Buy · %d" % int(entry.price), func() -> void:
				var bought: Dictionary = DeepEconomy.buy_case(home.profile, id)
				if bool(bought.get("ok", false)):
					DeepAudio.play("keep")
					home.cheer("%s into the vault" % DeepUi.skill_name(stone), DeepUi.GOOD)
					home.profile_changed.emit(), 14, DeepUi.ACCENT)
			buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			buy.disabled = int(home.profile.get("gold", 0)) < int(entry.price)
			buy.tooltip_text = ("It goes into your vault%s." % (" and yours is sold for %d gold" % DeepStone.value(own) if not own.is_empty() else "")) if not buy.disabled else "You have %d gold." % int(home.profile.get("gold", 0))
			DeepUi.voice(buy, "buy")
		card.mouse_entered.connect(func() -> void: home.hover_stone(card, stone))
	home.enter(panel, 0.08)

static func _yours_beside(parent: Node, stone: Dictionary, own: Dictionary) -> void:
	## The stone of the same skill already in the vault, set beside one for sale: its grade,
	## its marks and how far the one on offer is above or below it.
	var plate := DeepUi.panel(parent, Color(0, 0, 0, 0.22), Color(1, 1, 1, 0.06), 6, 6)
	var row := DeepUi.hbox(plate, 8)
	if own.is_empty():
		DeepUi.icon(row, "spark", 18, StoneCard.PIP_NEW)
		DeepUi.label(row, "A skill you don't have yet", 12, StoneCard.PIP_NEW)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		return
	StoneCard.mini(row, own, 38.0)
	var words := DeepUi.vbox(row, 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grade: Dictionary = DeepStone.grade(own)
	var names := DeepUi.hbox(words, 6)
	DeepUi.label(names, "Yours", 12, DeepUi.MUTED)
	DeepUi.label(names, "%s · %d" % [str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), int(grade.score)], 12, DeepUi.tier_color(str(grade.tier)))
	DeepUi.label(words, "%d ct · %s · %s" % [int(own.get("carat", 1)), DeepContent.cut_name(int(own.get("cut", 0))), DeepContent.clarity_name(int(own.get("clarity", 0)))], 11, DeepUi.DIM)
	var gap: int = int(DeepStone.grade(stone).score) - int(grade.score)
	var tone: Color = DeepUi.GOOD if gap > 0 else (DeepUi.BAD if gap < 0 else DeepUi.MUTED)
	var lead := DeepUi.label(row, "%+d" % gap if gap != 0 else "even", 15, tone)
	lead.tooltip_text = "The one on offer grades %s yours." % ("above" if gap > 0 else ("below" if gap < 0 else "level with"))
	lead.mouse_filter = Control.MOUSE_FILTER_PASS

static func _bench(home: Control, parent: VBoxContainer) -> void:
	var panel := DeepUi.card(parent, DeepUi.LINE, 12)
	var box := DeepUi.vbox(panel, 8)
	DeepUi.section(box, "hammer", "The bench · once a day each")
	var row := DeepUi.vbox(box, 8)
	var services: Array = [["wheel", "cut", "The Wheel", "Recut a vault stone's Cut. 1 in 25 break.", "Its Cut always changes, up or down, and 1 in 25 stones break on the wheel."],
		["oven", "flame", "The Oven", "Refire a vault stone's Clarity. 1 in 25 break.", "Its Clarity, and what is frozen inside, always changes, and 1 in 25 stones break in the oven."],
		["contract", "contract", "Trade-up contract", "Five stones of one grade make one of the next.", "Five stones of one grade go in; one of the next grade comes out."]]
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
		DeepUi.label(words, str(entry[3]), 12, DeepUi.MUTED)
		if used:
			DeepUi.pill(top, "check", "Used today", DeepUi.MUTED, 11).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
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
	for commission in list:
		_commission_row(home, box, commission)
	DeepUi.spacer(box, false)
	var price: int = DeepEconomy.reroll_price(home.profile)
	DeepUi.label(box, "Swapping one is free once a day, then %d gold and more each time." % int(DeepContent.constant("commission_reroll_gold", 10)) if price == 0 else "The next swap costs %d gold." % price, 12, DeepUi.DIM)
	home.enter(panel, 0.1)

static func _commission_row(home: Control, box: VBoxContainer, commission: Dictionary) -> void:
	var skill_key: String = str(commission.get("skill", ""))
	var skill: Dictionary = DeepContent.skill(skill_key)
	var hue: Color = DeepUi.color(str(skill.get("color", "WHITE")))
	var done: bool = bool(commission.get("done", false))
	var on_tray: Array = home.profile.get("tray", []).filter(func(s: Dictionary) -> bool: return DeepEconomy.meets(commission, s))
	var kept: Dictionary = DeepEconomy.vault_fill(home.profile, commission)
	var ready: bool = not done and (not on_tray.is_empty() or not kept.is_empty())
	var card := DeepUi.card(box, Color(DeepUi.GOOD if ready else hue, 0.5 if not done else 0.15), 10, Color(0.05, 0.07, 0.11, 0.9))
	var column := DeepUi.vbox(card, 6)
	var row := DeepUi.hbox(column, 10)
	var known: bool = home.profile.get("vault", {}).has(skill_key) or home.profile.get("seen", []).has(skill_key)
	DeepUi.icon(row, GemIcons.emblem(skill_key), 34, Color(hue, 0.95 if known else 0.45), str(skill.get("text", "")))
	var words := DeepUi.vbox(row, 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var names := DeepUi.hbox(words, 6)
	DeepUi.label(names, str(skill.get("name", skill_key)), 15, hue.lightened(0.25) if not done else DeepUi.DIM)
	if DeepProfile.wanted(home.profile).has(skill_key):
		DeepUi.icon(names, "star", 13, DeepUi.ACCENT_HI, "Wanted")
	var need: String = DeepEconomy.need_text(commission.get("need", {}))
	DeepUi.label(words, "Any %s" % str(skill.get("name", skill_key)) if need.is_empty() else need.capitalize(), 12, DeepUi.MUTED)
	if done:
		DeepUi.pill(row, "check", "Paid %d" % int(commission.get("paid", 0)), DeepUi.GOOD, 11)
		return
	DeepUi.stat(row, "coins", "%d+" % int(commission.get("reward", 0)), DeepUi.ACCENT, 14, "Pays %d gold, or a quarter more than the stone would sell for if it is finer than that." % int(commission.get("reward", 0)))
	var id: String = str(commission.get("id", ""))
	var reroll := DeepUi.icon_button(row, "reroll", "", func() -> void:
		if bool(DeepEconomy.reroll(home.profile, id).get("ok", false)):
			DeepAudio.play("ui_confirm", {"volume": 0.7})
			home.profile_changed.emit(), 12, DeepUi.MUTED)
	var price: int = DeepEconomy.reroll_price(home.profile)
	reroll.disabled = int(home.profile.get("gold", 0)) < price
	reroll.tooltip_text = ("Swap it for another skill · %s" % ("free" if price == 0 else "%d gold" % price)) if not reroll.disabled else "You have %d gold. A swap costs %d." % [int(home.profile.get("gold", 0)), price]
	if not on_tray.is_empty():
		var go := DeepUi.icon_button(column, "flag", "On your tray: turn it in", func() -> void:
			home._appraise_pick = str(on_tray[0].id)
			home._vault_view = "unappraised"
			home.open("vault", true), 13, DeepUi.GOOD)
		go.size_flags_horizontal = Control.SIZE_SHRINK_END
	elif not kept.is_empty():
		var sure: bool = home._commission_sure == id
		var hand := DeepUi.icon_button(column, "flag", ("Give up your %s · +%d" if sure else "Turn in yours · +%d") % ([DeepUi.skill_name(kept), DeepEconomy.payout(commission, kept)] if sure else [DeepEconomy.payout(commission, kept)]), func() -> void:
			if not sure:
				home._commission_sure = id
				DeepAudio.play("ui_deny", {"volume": 0.5})
				home._render()
				return
			if bool(DeepEconomy.turn_in_vault(home.profile, id).get("ok", false)):
				home._commission_sure = ""
				DeepAudio.play("sell")
				home.profile_changed.emit(), 13, DeepUi.BAD if sure else DeepUi.GOOD)
		hand.size_flags_horizontal = Control.SIZE_SHRINK_END
		hand.tooltip_text = "The %s in your vault meets it. Handing it over takes it out of the vault and every loadout." % DeepUi.skill_name(kept)

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
	var stones: Array = StoneBrowser.sorted(home, home.profile.get("vault", {}).values(), "bench")
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
				home._rework_pick = skill
				home._render())
	home.enter(picker, 0.05)
	var side := DeepUi.card(columns, Color(DeepUi.ACCENT, 0.4), 16)
	side.custom_minimum_size.x = 460
	var side_box := DeepUi.vbox(side, 10)
	var stone: Dictionary = DeepProfile.owned(home.profile, home._rework_pick)
	if stone.is_empty():
		DeepUi.section(side_box, "cut" if wheel else "flame", "On the wheel" if wheel else "In the oven")
		DeepUi.spacer(side_box, false)
		DeepUi.label(side_box, "Choose a stone from your vault.", 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.spacer(side_box, false)
		home.enter(side, 0.1)
		return
	DeepUi.section(side_box, "cut" if wheel else "flame", "%s %s" % ["On the wheel:" if wheel else "In the oven:", DeepUi.skill_name(stone)])
	var reveal := Rework.new(stone, kind, 130.0)
	reveal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side_box.add_child(reveal)
	DeepUi.section(side_box, "scales", "What it could come out as", DeepUi.MUTED, 12)
	var names: Array = DeepContent.cuts() if wheel else DeepContent.clarities()
	var parts: Array = []
	var index: int = 0
	for entry in DeepEconomy.rework_odds(stone, kind):
		if str(entry[0]) == "break":
			parts.append({"label": "Breaks", "share": float(entry[1]), "color": DeepUi.BAD})
		else:
			parts.append({"label": str(names[int(entry[0])].get("name", "")), "share": float(entry[1]), "color": DeepUi.ACCENT.lerp(DeepUi.GOOD, float(int(entry[0])) / float(maxi(1, names.size() - 1))) if wheel else (Color("c58bff") if int(entry[0]) < DeepContent.clear_index() else Color("9fe8ff"))})
		index += 1
	side_box.add_child(HomeParts.OddsBar.new(parts))
	DeepUi.stat(side_box, "split_shield", "1 in 25 stones break %s." % ("on the wheel" if wheel else "in the oven"), DeepUi.BAD, 13)
	DeepUi.spacer(side_box, false)
	var refusal: String = DeepEconomy.rework_refusal(home.profile, home._rework_pick, kind)
	var price: int = DeepEconomy.rework_price(stone)
	## The button, reached from inside its own press, so it can go dark while the wheel turns.
	var pressed: Array = []
	var go := DeepUi.primary(side_box, "cut" if wheel else "flame", ("Recut %s · %d" if wheel else "Fire %s · %d") % [DeepUi.skill_name(stone), price], func() -> void:
		var result: Dictionary = DeepEconomy.rework(home.profile, home._rework_pick, kind)
		if not bool(result.get("ok", false)):
			return
		if not pressed.is_empty() and is_instance_valid(pressed[0]):
			(pressed[0] as Button).disabled = true
		home.touch()
		if bool(result.broke):
			home._rework_pick = ""
		reveal.finished.connect(func() -> void:
			home.get_tree().create_timer(1.6).timeout.connect(func() -> void: home.profile_changed.emit()), CONNECT_ONE_SHOT)
		reveal.play(int(result.now), bool(result.broke)), 17)
	pressed.append(go)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(300, 50)
	go.disabled = not refusal.is_empty()
	go.tooltip_text = refusal if not refusal.is_empty() else "The price follows the stone's worth."
	DeepUi.label(side_box, refusal if not refusal.is_empty() else "The price follows the stone's worth.", 12, DeepUi.BAD if not refusal.is_empty() else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	home.enter(side, 0.1)

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
	var words: String = "Sign the contract"
	if signable:
		words = ("Sign it, vault stones and all · %d gold" if giving_up and home._contract_sure else "Sign the contract · %d gold") % int(preview.fee)
	var sign := DeepUi.primary(sign_row, "contract", words, func() -> void:
		if giving_up and not home._contract_sure:
			home._contract_sure = true
			DeepAudio.play("ui_deny", {"volume": 0.6})
			home._render()
			return
		_sign_contract(home), 17, DeepUi.BAD if giving_up and home._contract_sure else tone)
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
	for entry in home.paged(box, "contract", listed, CONTRACT_PAGE):
		var stone: Dictionary = entry.stone
		var ref: String = str(entry.ref)
		var placed: bool = home._contract.has(ref)
		var fits: bool = tier.is_empty() or str(DeepStone.grade(stone).tier) == tier
		var tile := StoneCard.tile(grid, stone, 72)
		if bool(entry.vault):
			home.tile_mark(tile, "chest", DeepUi.INFO, "In your vault: put in a contract, its skill is no longer kept")
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
