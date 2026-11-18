extends RefCounted
## Descend: where a run starts. The mines as a cross-section on the left; on the right, which
## of the two ways down the party is taking (an expedition into a mine, or the day's seam), the
## mine, who goes down and wearing what, and the button that sets out. The button names the
## delver and the fare, so it is never a surprise who goes down or what it costs.

const MineMap = preload("res://view/home/mine_map.gd")
const Roster = preload("res://view/home/roster.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Plates = preload("res://view/ui/plates.gd")

const DAILY_KIND_WORDS: Dictionary = {"rail": "Rail rule", "hazard": "Hazard", "blessing": "Blessing", "twist": "Twist"}
const SIDE_WIDTH: float = 450.0

static func build(home: Control, content: VBoxContainer) -> void:
	if DeepUi.phone:
		load("res://view/phone/descend_phone.gd").build(home, content)
		return
	var daily: bool = not str(home.lobby.get("daily", "")).is_empty()
	var columns := DeepUi.hbox(content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map := MineMap.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size = Vector2(560, 560)
	columns.add_child(map)
	## The map of the party's Hazard tier: its own records, its own carats. On the day's seam,
	## how far today's digs have gone instead.
	var tier: int = int(home.lobby.get("hazard", 0))
	var records: Dictionary = DeepEconomy.daily_reach(home.profile, str(home.lobby.get("daily", ""))) if daily else DeepProfile.mine_records(home.profile, tier)
	map.profile = home.profile
	map.show_mines(DeepContent.mines_in_order(), records, str(home.lobby.get("mine", "")), home.is_host, DeepProfile.unlocked_characters(home.profile), daily,
		tier, DeepProfile.hazard_top(home.profile), party_cap(home.lobby))
	map.chosen.connect(func(key: String) -> void:
		DeepAudio.play("ui_confirm", {"volume": 0.7})
		home.mine_chosen.emit(key))
	map.hazard_chosen.connect(func(picked: int) -> void:
		DeepAudio.play("ui_confirm", {"volume": 0.7})
		home.hazard_chosen.emit(picked))
	home.enter(map)
	## The day's seam stands its cards a little closer (10, not 12): with the K4 par lines it
	## runs nearly to the foot of the screen (November 16, 2026).
	var side := DeepUi.vbox(columns, 10 if daily else 12)
	side.custom_minimum_size.x = SIDE_WIDTH
	_mode_switch(home, side, daily)
	if daily:
		_daily_view(home, side)
	else:
		_expedition_view(home, side)
	DeepUi.spacer(side, false)
	var go_card := DeepUi.card(side, Color(DeepUi.ACCENT, 0.3), 14)
	_go(home, DeepUi.vbox(go_card, 8))
	home.enter(go_card, 0.1)

static func party_cap(lobby: Dictionary) -> int:
	## The highest Hazard tier every member of the party has unlocked.
	var cap: int = DeepContent.hazard_max()
	for id in lobby.get("order", []):
		var member: Dictionary = lobby.get("members", {}).get(id, {})
		if bool(member.get("connected", true)):
			cap = mini(cap, int(member.get("hazard_top", 0)))
	return maxi(0, cap)

static func _mode_switch(home: Control, side: VBoxContainer, daily: bool) -> void:
	## Expedition or the day's seam. The host chooses for the party; a guest sees which.
	var row := DeepUi.hbox(side, 6)
	for entry in [["", "descend", "Expedition"], ["daily", "calendar", "Daily dig"]]:
		var mode: String = str(entry[0])
		var on: bool = (mode == "daily") == daily
		var button := DeepUi.tab_button(row, str(entry[1]), str(entry[2]), on, func() -> void:
			if home.is_host:
				home.daily_chosen.emit(DeepEconomy.today() if mode == "daily" else ""), 14)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not home.is_host and not on:
			button.disabled = true
			button.tooltip_text = "The host chooses where the party goes."
		if mode == "daily" and not daily and DeepEconomy.daily_state(home.profile) == "fresh":
			HomeParts.pin(button, 0, home.PIP_NEW, true)
			button.tooltip_text = "Today's seam: not dug yet"

static func _expedition_view(home: Control, side: VBoxContainer) -> void:
	## The expedition: which mine, and who goes down wearing what.
	var chosen_key: String = str(home.lobby.get("mine", DeepContent.starter_mine()))
	var mine: Dictionary = DeepContent.mine(chosen_key)
	var tier: int = int(home.lobby.get("hazard", 0))
	var record: Dictionary = DeepProfile.mine_records(home.profile, tier).get(chosen_key, {})
	var trip := DeepUi.card(side, Color(DeepUi.ACCENT, 0.4), 16)
	var trip_box := DeepUi.vbox(trip, 6)
	DeepUi.section(trip_box, "descend", "Stratum %s" % MineMap.numeral(chosen_key))
	DeepUi.title(trip_box, str(mine.get("name", chosen_key)), 26, DeepUi.PAPER)
	DeepUi.wrap(trip_box, str(mine.get("text", "")), 13, DeepUi.MUTED)
	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", 6)
	facts.add_theme_constant_override("v_separation", 6)
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trip_box.add_child(facts)
	DeepUi.pill(facts, "stairs", "deepest %d" % int(record.get("deepest", 0)), DeepUi.INFO, 12)
	if DeepContent.is_endless(chosen_key):
		DeepUi.pill(facts, "crown", "endless", DeepUi.ACCENT, 12, "A Warden every %d floors, and no bottom." % DeepDescent.warden_every(mine))
	else:
		var crowns: int = mine.get("warden_depths", []).size() + 1
		## What each crown pays the first time it falls, in the order they stand.
		var purses: Array = []
		for index in range(crowns - 1):
			purses.append(str(DeepEconomy.warden_purse(chosen_key, index)))
		purses.append(str(DeepEconomy.conquest_purse(chosen_key)))
		DeepUi.pill(facts, "crown", "%d of %d crowns" % [mini(record.get("wardens", []).size(), crowns), crowns], DeepUi.ACCENT, 12,
			"%d Wardens and the final boss at depth %d.\nThe first time each falls it pays %s gold." % [crowns - 1, DeepContent.mine_bottom(chosen_key),
				"%s and %s" % [", ".join(purses.slice(0, purses.size() - 1)), purses.back()]])
	DeepUi.pill(facts, "pick", DeepUi.plural(int(record.get("runs", 0)), "run"), DeepUi.MUTED, 12)
	var band: Dictionary = DeepForge.carat_band(DeepForge.at_hazard(mine, tier), 1)
	var deeper: bool = chosen_key != DeepContent.starter_mine()
	if not band.is_empty():
		var lift: int = DeepForge.hazard_carats(mine, tier)
		var light: float = _loadout_luck(home, str(home.profile.get("current_character", DeepContent.starter_character())))
		DeepUi.pill(facts, "gem", "up to %d ct%s" % [int(band.cap), MineMap.luck_stars(light)], DeepUi.ACCENT_HI if lift > 0 else DeepUi.PAPER, 12, "Stones usually up to %d carats, never over %d.%s%s" % [int(band.soft), int(band.cap),
			(" Hazard %d lifts both by %d." % [tier, lift]) if lift > 0 else "", MineMap.luck_words(light)])
	if deeper:
		## What a start here opens with: the mine's purse, and for a Birthstone that grows all run
		## (a Renown, a Bloodroot) its head start, in the same capsule so the card stands no taller.
		var opens: Dictionary = head_start(home, chosen_key)
		DeepUi.pill(facts, "ore", "start with %d pyrite%s" % [int(mine.get("start_pyrite", 0)), str(opens.get("and", ""))], DeepUi.ORE, 12,
			("Starting here costs a fare of %d gold, paid by each delver at the shaft head. Each starts with this much pyrite, and every socket not bought is offered three temporary stones that shatter when the run ends." % DeepEconomy.fare(chosen_key))
				+ str(opens.get("tip", ""))).name = "StartWith"
	var batch: Array = mine.get("batch", [])
	if not batch.is_empty():
		var found: Array = batch.filter(func(k: Variant) -> bool: return home.profile.get("vault", {}).has(str(k)) or home.profile.get("seen", []).has(str(k)))
		var skills := HFlowContainer.new()
		skills.add_theme_constant_override("h_separation", 3)
		skills.add_theme_constant_override("v_separation", 3)
		skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trip_box.add_child(skills)
		DeepUi.label(skills, "%d skills first found here · %d found" % [batch.size(), found.size()], 12, DeepUi.MUTED)
		DeepUi.gap(skills, 4)
		for key in batch:
			var def: Dictionary = DeepContent.skill(str(key))
			var known: bool = found.has(key)
			DeepUi.icon(skills, GemIcons.emblem(str(key)), 15, DeepUi.color(str(def.get("color", ""))) if known else DeepUi.DIM,
				str(def.get("name", key)) if known else "Not found yet")
	home.enter(trip)
	_going_down(home, side)

static func head_start(home: Control, mine_key: String) -> Dictionary:
	## What the Birthstone the chosen delver wears opens a start in this mine with: a Renown its
	## Trophies, a Bloodroot its max health, for the mines skipped
	## (`DeepDescent.birthstone_head_start`). {and: " and 24 Trophies", said: "Renown opens with
	## 24 Trophies.", tip: a line more for a tooltip}; {} for any other stone, and in the first mine.
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	var worn: String = DeepProfile.worn_birthstone(home.profile, current)
	var given: Dictionary = DeepDescent.birthstone_head_start({"birthstone": DeepContent.birthstone_def(current, worn)}, mine_key)
	var words: String = Plates.head_start_words(given)
	if words.is_empty():
		return {}
	var said: String = Plates.birth_opens(str(DeepStone.birthstone(current, worn).get("name", "")), given)
	return {"and": " and %s" % words, "said": said, "tip": "\n%s A little under what the walk down would have grown it to." % said}

static func _going_down(home: Control, side: VBoxContainer) -> void:
	## Who goes down: a portrait for every delver (one click picks), and the chosen one's
	## sockets and dice. A socket opens their loadout on the Delvers page.
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	var character: Dictionary = DeepContent.character(current)
	var wear := DeepUi.card(side, DeepUi.LINE, 14)
	var box := DeepUi.vbox(wear, 9)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "person", "Going down as").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HomeParts.keycaps(head, ["Q", "E"], "Q and E step through the delvers")
	var faces := DeepUi.hbox(box, 7)
	for key in DeepContent.characters_in_unlock_order():
		var unlocked: bool = bool(home.profile.get("characters", {}).get(str(key), {}).get("unlocked", false))
		## Each plate is lit by the Birthstone that delver goes down in.
		var wears: Dictionary = Roster.worn_stone(home.profile, str(key)) if unlocked else {}
		var portrait := Roster.Portrait.new(str(key), Vector2(48, 48), not unlocked, str(key) == current, false, wears)
		portrait.tooltip_text = Roster.named(str(key), wears) if unlocked else "Locked. " + Roster.unlock_hint(str(key)) + "."
		faces.add_child(portrait)
		if unlocked:
			portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			portrait.tooltip_text += "\nRight-click for their page."
			var picked: String = str(key)
			var their_page := func() -> void:
				DeepAudio.play("ui_tap")
				home._roster_pick = picked
				home._roster_view = "dossier"
				home._bench_socket = -1
				home.open("delvers", true)
			## A finger held on the face opens their page, as a right-click does.
			load("res://view/ui/tips.gd").hold(portrait, their_page)
			portrait.gui_input.connect(func(event: InputEvent) -> void:
				if not event is InputEventMouseButton or not event.pressed:
					return
				if event.button_index == MOUSE_BUTTON_RIGHT:
					their_page.call()
				elif event.button_index == MOUSE_BUTTON_LEFT and picked != current:
					home.choose_character(picked))
			if str(key) != current:
				DeepUi.juice(portrait, 1.08)
		if bool(home.profile.get("characters", {}).get(str(key), {}).get("fresh", false)):
			HomeParts.pin(portrait, 0, home.PIP_NEW, true)
	DeepUi.title(box, DeepContent.character_title(current), 21, DeepUi.PAPER)
	var pills := DeepUi.hbox(box, 6)
	DeepUi.pill(pills, "heart", "%d HP" % int(character.get("hp", 0)), DeepUi.HP, 11)
	DeepUi.pill(pills, "spark", str(character.get("passive", {}).get("name", "Passive")), DeepUi.ACCENT, 11, str(character.get("passive", {}).get("text", "")))
	## The Birthstone in its own color, as the dossier wears it, not the info blue (Blue is guard):
	## the one they go down in, which may be a variant bought for them.
	var birth: Dictionary = Roster.worn_stone(home.profile, current)
	var birth_tone: Color = Roster.stone_tone(birth) if not birth.is_empty() else DeepUi.INFO
	DeepUi.pill(pills, "gem", str(birth.get("name", "Birthstone")), birth_tone, 11, str(birth.get("text", ""))).name = "WornStone"
	var loadout: Dictionary = DeepProfile.loadout(home.profile, current)
	var rail := DeepUi.hbox(box, 6)
	var home_bound: Array = barred(home, current)
	home.socket_strip(rail, current, loadout, 44.0, false, func(index: int) -> void: home.edit_loadout(current, index), home_bound, barred_tip(home))
	var dice := DeepUi.hbox(box, 6)
	dice.mouse_filter = Control.MOUSE_FILTER_PASS
	dice.tooltip_text = home.OWN_DICE
	for die in loadout.dice:
		var die_thumb := Thumbs.DieThumb.new(die, 30)
		die_thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		dice.add_child(die_thumb)
	var empty: int = 0
	for index in range(DeepProfile.open_sockets(home.profile, current)):
		if index < loadout.rail.size() and not loadout.rail[index] is Dictionary:
			empty += 1
	DeepUi.spacer(dice)
	## Travelling light or heavy: the stars the map shows, and what they do, why and how to lose
	## it, on a line of its own under the dice (S3).
	var light: float = _loadout_luck(home, current)
	var luck: Dictionary = luck_said(loaded(home, current))
	if not home_bound.is_empty():
		DeepUi.stat(dice, "cross_out", "%d stay home" % home_bound.size(), DeepUi.BAD, 12).tooltip_text = barred_tip(home)
	elif light != 0.0:
		var said := DeepUi.stat(dice, "gem", "%s %s" % [str(luck.short), MineMap.luck_stars(light).strip_edges()], DeepUi.GOOD if light > 0.0 else DeepUi.BAD, 12)
		said.tooltip_text = str(luck.tip)
		var why := DeepUi.wrap(box, str(luck.why), 12, DeepUi.MUTED)
		why.name = "LuckWhy"
	elif empty > 0:
		DeepUi.stat(dice, "gem", "%s empty" % DeepUi.plural(empty, "socket"), DeepUi.ACCENT, 12)
	else:
		DeepUi.label(dice, "Click a socket to change it", 12, DeepUi.DIM)
	home.enter(wear, 0.05)

static func _loadout_luck(home: Control, character: String) -> float:
	## The luck the delver's loadout puts on every stone found: see DeepDescent.loadout_luck.
	return DeepDescent.loadout_luck(loaded(home, character))

static func loaded(home: Control, character: String) -> int:
	## How many stones the delver's loadout sets in their open sockets.
	var rail: Array = DeepProfile.loadout(home.profile, character).rail
	var stones: int = 0
	for index in range(mini(rail.size(), DeepProfile.open_sockets(home.profile, character))):
		if rail[index] is Dictionary:
			stones += 1
	## Narrow Shaft lets only the first few down: luck counts what goes.
	var limit: int = DeepDescent.rail_limit(int(home.lobby.get("hazard", 0)))
	return stones if limit < 0 else mini(stones, limit)

static func barred(home: Control, character: String) -> Array:
	## The sockets whose stones the party's Hazard tier keeps home (Narrow Shaft): every stone
	## past the first three, left to right. [] below that tier.
	return DeepDescent.left_behind(DeepProfile.loadout(home.profile, character).rail, DeepProfile.open_sockets(home.profile, character),
		DeepDescent.rail_limit(int(home.lobby.get("hazard", 0))))

static func barred_tip(home: Control) -> String:
	## Why a stone crossed out on the rail stays home.
	return "Narrow Shaft (Hazard %d): only the first %d stones in your loadout go down, left to right. This one stays in the vault." % [
		int(home.lobby.get("hazard", 0)), DeepDescent.rail_limit(int(home.lobby.get("hazard", 0)))]

static func luck_key(parent: Node, stones: int, size: int = 11, short: bool = false) -> Button:
	## The phone's word for it: "4 loaded · -2 luck" as a key whose tap (or hold) brings up the
	## card that says why and how to lose it (S3). Null for a loadout of three.
	var luck: Dictionary = luck_said(stones)
	if luck.is_empty():
		return null
	var Tips: Script = load("res://view/ui/tips.gd")
	var Plates: Script = load("res://view/ui/plates.gd")
	var light: bool = DeepDescent.loadout_luck(stones) > 0.0
	var words: String = ("%+d luck" if short else "%d loaded · %+d luck") % ([int(DeepDescent.loadout_luck(stones))] if short else [stones, int(DeepDescent.loadout_luck(stones))])
	var key := DeepUi.icon_button(parent, "gem", words, Callable(), size, DeepUi.GOOD if light else DeepUi.BAD)
	key.flat = true
	key.custom_minimum_size.y = DeepUi.pt(DeepUi.FINGER_LEAST)
	key.name = "LuckKey"
	Tips.attach(key, func() -> Control: return Plates.words(str(luck.short), str(luck.tip)))
	key.pressed.connect(func() -> void: Tips.open_sheet(key))
	return key

static func luck_said(stones: int) -> Dictionary:
	## Travelling light or heavy, said with its cause and its cure (S3, November 13, 2026):
	## {short: "Travelling heavy · -2 luck", why: "4 stones loaded (3 travel light): -2 luck.
	## Take one out to lose it.", tip: the same, longer}. {} for a loadout of three.
	var luck: float = DeepDescent.loadout_luck(stones)
	if luck == 0.0:
		return {}
	var base: int = int(DeepContent.constant("loadout_luck_base", 3))
	var per: int = int(DeepContent.constant("loadout_luck_per_stone", 2))
	var loaded_words: String = "%s loaded" % DeepUi.plural(stones, "stone")
	if luck < 0.0:
		var over: int = stones - base
		return {"short": "Travelling heavy · %+d luck" % int(luck), "word": "Travelling heavy",
			"why": "%s (%d travel light): %+d luck. Take %s out to lose it." % [loaded_words, base, int(luck), "one" if over == 1 else str(over)],
			"tip": "%s, and %d travel light: every stone the mine gives you rolls %d luck worse, %d for each stone over %d. Take %s out to lose it." % [loaded_words, base, -int(luck), per, base, "one" if over == 1 else str(over)]}
	return {"short": "Travelling light · %+d luck" % int(luck), "word": "Travelling light",
		"why": "%s (%d is even): %+d luck, %d for each socket left empty." % [loaded_words, base, int(luck), per],
		"tip": "%s, and %d is even: every stone the mine gives you rolls %d luck better, %d for each socket left empty." % [loaded_words, base, int(luck), per]}

static func _daily_tone(kind: String) -> Color:
	match kind:
		"hazard": return DeepUi.BAD
		"blessing": return DeepUi.GOOD
		"twist": return Color("c58bff")
	return DeepUi.INFO

static func borrowed_words(name: String, plan: Dictionary) -> String:
	## "Borrowed Birthstone: Florin's Blackjack": whose stone the day borrows, and which of their three.
	return "%s: %s's %s" % [name, DeepContent.character_title(str(plan.get("birthstone", ""))).get_slice(",", 0), str(Roster.daily_stone(plan).get("name", "Birthstone"))]

static func lent_words(plan: Dictionary) -> String:
	## The delver the day lends, named with the Birthstone it lends them when that is not their
	## first: "Ardor, wearing Rampart". A borrowed stone is named by its own name.
	var character: String = DeepEconomy.daily_lapidary(plan)
	var stone: Dictionary = Roster.daily_stone(plan)
	if Roster.is_first(character, stone):
		return DeepContent.character_title(character)
	return "%s, wearing %s" % [str(DeepContent.character(character).get("name", character)), str(stone.get("name", "Birthstone"))]

static func lent_note(plan: Dictionary) -> String:
	## What is said under the name about a stone that is not the delver's first: it is the
	## day's, whether or not anyone owns it. "" on a day that lends the first.
	var character: String = DeepEconomy.daily_lapidary(plan)
	var stone: Dictionary = Roster.daily_stone(plan)
	if Roster.is_first(character, stone):
		return ""
	if str(stone.get("character", "")) != character:
		return "%s is %s's Birthstone, borrowed for the day." % [str(stone.get("name", "")), str(DeepContent.character(str(stone.get("character", ""))).get("name", ""))]
	return "%s is lent for the day, whether or not you own it." % str(stone.get("name", ""))

static func _daily_view(home: Control, side: VBoxContainer) -> void:
	## The day's seam: the same for everyone on this build today. Its four cards, how it is
	## scored and paid, where this player stands today, and the delver it lends the party.
	var date: String = str(home.lobby.get("daily", ""))
	if date.is_empty():
		date = DeepEconomy.today()
	var plan: Dictionary = DeepEconomy.daily_plan(date)
	var mine: Dictionary = DeepContent.mine(str(plan.mine))
	var seam := DeepUi.card(side, Color(DeepUi.ACCENT, 0.4), 14)
	var box := DeepUi.vbox(seam, 4)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "calendar", "The daily dig").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left: int = DeepEconomy.seconds_to_tomorrow()
	var clock := DeepUi.stat(head, "hourglass", "%dh %02dm left" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 12, "A new seam opens every day at midnight UTC.")
	countdown(home, clock, date, " left")
	## The seam's name, and that it is everyone's, on one line; each card's name, kind and words
	## in one paragraph (November 16, 2026). Laid name over words, with the par lines, the streak
	## and the last seven days (K4) under them, the page ran up to 100 points past the foot of the
	## screen on most days (the Descend button out of sight); every word is still here.
	var title_row := DeepUi.hbox(box, 8)
	var title := DeepUi.title(title_row, "%s, and on down" % str(mine.get("name", plan.mine)), 22, DeepUi.PAPER)
	title.tooltip_text = "It starts at the top of the Quarry and goes on through every mine, as deep as you want to go."
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(title_row, "Same for everyone today", 12, DeepUi.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in [str(plan.rail)] + plan.get("mods", []):
		var mod: Dictionary = DeepEconomy.daily_mod(str(key))
		var kind: String = str(mod.get("kind", "hazard"))
		var hue: Color = _daily_tone(kind)
		var line := DeepUi.hbox(box, 8)
		DeepUi.icon(line, str(mod.get("glyph", "spark")), 20, hue, str(DAILY_KIND_WORDS.get(kind, ""))).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name: String = str(mod.get("name", key))
		if str(key) == "DROUGHT" and plan.has("drought"):
			name = "%s: no %s" % [name, str(DeepContent.color(str(plan.drought)).get("name", plan.drought))]
		if str(key) == "BORROWED_BIRTHSTONE" and plan.has("birthstone"):
			name = borrowed_words(name, plan)
		line.add_child(_card_words(name, str(DAILY_KIND_WORDS.get(kind, "")), str(mod.get("text", "")), hue.lightened(0.1)))
	var knee: int = int(DeepContent.constant("daily_score_knee", 1000))
	var best: Dictionary = DeepEconomy.daily_best(home.profile, date)
	var standing := DeepUi.hbox(box, 8)
	## A Hazard tier pays more gold for the same score.
	var tier: int = int(home.lobby.get("hazard", 0))
	var paid_words: String = "Paid in gold for your score" if tier <= 0 else "Score paid ×%s on Hazard %d" % [String.num(DeepEconomy.daily_gold_mult(tier), 2), tier]
	## Broken into lines by hand: the engine's tooltip never wraps, and one line ran off the screen.
	DeepUi.stat(standing, "coin", paid_words, DeepUi.ACCENT, 12,
		"Your score is the worth of the stones you bring up\nplus the pyrite you carry. A fall scores only what the salvage dice save.\nA score pays %d gold at %d, and half the rate past that,\nmore on a Hazard tier: twice as much at Hazard %d.\nNothing you find is kept." % [DeepEconomy.daily_payout(knee), knee, DeepContent.hazard_max()]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match DeepEconomy.daily_state(home.profile, date):
		"locked":
			## Anyone may dig it before then, host or guest, but unpaid.
			DeepUi.pill(standing, "lock", "Unpaid until the Quarry falls", DeepUi.DIM, 11, "You are paid from the day you beat the Quarry.")
		"played":
			DeepUi.pill(standing, "star", "Best today %d" % int(best.score), DeepUi.GOOD, 11, "Paid %d gold. Another dig today pays only the gold its score adds." % int(best.gold))
		_:
			DeepUi.pill(standing, "star", "Not dug yet today", DeepUi.ACCENT, 11)
	par_block(home, box, date)
	home.enter(seam)
	var seat: int = maxi(0, home.lobby.get("order", []).find(home.local_id))
	var character: String = DeepEconomy.daily_lapidary(plan)
	var lent := DeepUi.card(side, DeepUi.LINE, 14)
	var lent_box := DeepUi.vbox(lent, 6)
	DeepUi.section(lent_box, "person", "Lent for the day")
	var row := DeepUi.hbox(lent_box, 12)
	## The Birthstone the day lends with them: one of their three, or a borrowed one.
	var day_stone: Dictionary = Roster.daily_stone(plan)
	row.add_child(Roster.Portrait.new(character, Vector2(60, 60), false, false, false, day_stone))
	var facts := DeepUi.vbox(row, 2)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.title(facts, lent_words(plan), 18, DeepUi.PAPER).name = "LentAs"
	DeepUi.wrap(facts, "The whole party goes down as this delver, with the stones and dice the day lends. Nothing of yours goes down.", 12, DeepUi.MUTED)
	if not lent_note(plan).is_empty():
		DeepUi.wrap(facts, lent_note(plan), 12, Roster.stone_tone(day_stone)).name = "LentStone"
	var rail := DeepUi.hbox(lent_box, 6)
	var stones: Array = DeepEconomy.daily_rail(plan, character, seat)
	var sockets: Array = DeepContent.character(character).get("sockets", [])
	for index in range(sockets.size()):
		var stone: Variant = stones[index] if index < stones.size() else null
		home.kit_socket(rail, str(sockets[index]), stone if stone is Dictionary else {}, 40.0)
	home.kit_socket(rail, "BIRTHSTONE", day_stone, 40.0)
	home.enter(lent, 0.05)

static func _card_words(name: String, kind_words: String, said: String, tone: Color) -> RichTextLabel:
	## One of the day's cards as a paragraph: its name in its kind's colour, the kind, then what
	## it does, wrapped at the side column's width.
	var words := RichTextLabel.new()
	words.fit_content = true
	words.scroll_active = false
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## A wrapping rich text beside a sized sibling stands no width (and draws nothing) unless it
	## is given one: the column's inside, less the card's margins and the mark.
	words.custom_minimum_size.x = SIDE_WIDTH - 28.0 - 28.0
	DeepUi.set_text_size(words, 12)
	words.push_font_size(DeepUi.readable(14))
	words.push_color(tone)
	words.add_text(name)
	words.pop()
	words.pop()
	if not kind_words.is_empty():
		words.push_font_size(DeepUi.readable(11))
		words.push_color(DeepUi.DIM)
		words.add_text("  " + kind_words)
		words.pop()
		words.pop()
	words.push_color(DeepUi.MUTED)
	words.add_text("  " + said)
	words.pop()
	return words

static func countdown(home: Control, clock: HBoxContainer, date: String, after: String) -> void:
	## Keeps the day's countdown true while the page stands, and when the day turns, turns the
	## page with it (X9): the new seam chosen for the party, its lent delver's picture taken
	## first so it never shows as a blank stand-in, then the page drawn again.
	var ticker := Timer.new()
	ticker.wait_time = 15.0
	ticker.autostart = true
	clock.add_child(ticker)
	var value: Node = clock.get_node_or_null("Value")
	ticker.timeout.connect(func() -> void:
		if not is_instance_valid(home) or not is_instance_valid(clock):
			return
		var left: int = DeepEconomy.seconds_to_tomorrow()
		if value is Label:
			(value as Label).text = "%dh %02dm%s" % [left / 3600, (left % 3600) / 60, after]
		var today: String = DeepEconomy.today()
		if today == date:
			return
		ticker.stop()
		warm_daily(today, func() -> void:
			if not is_instance_valid(home):
				return
			DeepEconomy.roll_day(home.profile)
			if home.is_host:
				home.daily_chosen.emit(today)
			home._render()))

static func warm_daily(date: String, then: Callable = Callable()) -> void:
	## Takes the picture of the day's lent Birthstone ahead of the page that shows it (X9: Ill
	## Omen drew as a blank cushion right after the day turned). `then` once it is ready.
	var stone: Dictionary = Roster.daily_stone(DeepEconomy.daily_plan(date))
	if stone.is_empty() or DeepUi.headless():
		if then.is_valid():
			then.call()
		return
	var called: Array = [false]
	var once := func(_texture: Variant = null) -> void:
		if called[0]:
			return
		called[0] = true
		if then.is_valid():
			then.call()
	if Thumbs.request(Thumbs.gem_key(stone), "gem", {"stone": stone}, once) != null:
		once.call()
		return
	## Never held up for long by a slow picture.
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.create_timer(2.0).timeout.connect(once)

## The par lines' own colors: bronze, silver and gold.
const MEDAL_TONES: Dictionary = {"BRONZE": Color("d39a62"), "SILVER": Color("c9d3e2"), "GOLD": Color("ffcf5a")}

static func par_block(home: Control, box: VBoxContainer, date: String) -> void:
	## The day's par lines with the gold each pays, how far the day's best is from the next one,
	## the streak of days dug, and the last seven days (K4, November 13, 2026). Local: a Steam
	## board comes later (Todo.md).
	var phone: bool = DeepUi.phone
	var best: int = int(DeepEconomy.daily_best(home.profile, date).score)
	var played: bool = DeepEconomy.daily_played(home.profile, date)
	var lines := DeepUi.hbox(box, int(DeepUi.pt(4)) if phone else 6)
	lines.name = "ParLines"
	var next: Dictionary = {}
	for line in DeepEconomy.daily_par(date):
		var medal: String = str(line.medal)
		var reached: bool = played and best >= int(line.score)
		if not reached and next.is_empty():
			next = line
		var tone: Color = MEDAL_TONES.get(medal, DeepUi.ACCENT)
		var chip := DeepUi.pill(lines, "check" if reached else "crown", "%s %d · +%d" % [str(DeepEconomy.DAILY_MEDAL_NAMES.get(medal, medal)), int(line.score), int(line.gold)],
			tone if reached else tone.darkened(0.25), 11, "%s par: a day's best of %d pays %d gold more, once." % [str(DeepEconomy.DAILY_MEDAL_NAMES.get(medal, medal)), int(line.score), int(line.gold)])
		if not reached:
			chip.modulate.a = 0.8
	var standing := DeepUi.hbox(box, int(DeepUi.pt(6)) if phone else 8)
	standing.name = "ParStanding"
	if played and not next.is_empty():
		DeepUi.label(standing, "%d to %s" % [int(next.score) - best, str(DeepEconomy.DAILY_MEDAL_NAMES.get(str(next.medal), "")).to_lower()], 11, DeepUi.MUTED)
	elif played:
		DeepUi.label(standing, "Every par line reached today", 11, MEDAL_TONES.GOLD)
	var streak: int = DeepEconomy.daily_streak(home.profile, date)
	DeepUi.stat(standing, "flame", "%d-day streak" % streak if streak > 0 else "No streak yet", DeepUi.ACCENT_HI if streak > 0 else DeepUi.DIM, 11,
		"Days in a row with the day's seam dug. Dig today to keep it.")
	DeepUi.spacer(standing)
	## The last seven days dug: a dot in the colour of the best line reached, the score under it.
	var recent: Array = DeepEconomy.daily_recent(home.profile, 7)
	if recent.is_empty():
		return
	## On the phone a row of their own, under the streak: beside "Every par line reached today"
	## and the streak, seven scores ran the page past the screen's right edge (November 16, 2026).
	var days_row: HBoxContainer = standing
	if phone:
		days_row = DeepUi.hbox(box, 0)
		days_row.name = "LastDaysRow"
		DeepUi.spacer(days_row)
	var days := DeepUi.hbox(days_row, int(DeepUi.pt(3)) if phone else 4)
	days.name = "LastDays"
	recent.reverse()
	for day in recent:
		var cell := DeepUi.vbox(days, 0)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var medal: String = str(day.medal)
		DeepUi.icon(cell, "crown" if not medal.is_empty() else "calendar", DeepUi.glyph_px(10), MEDAL_TONES.get(medal, DeepUi.DIM)).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.label(cell, str(int(day.score)), 11, DeepUi.PAPER if not medal.is_empty() else DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		cell.tooltip_text = "%s: best %d%s, %d gold" % [str(day.date), int(day.score), (" · " + str(DeepEconomy.DAILY_MEDAL_NAMES.get(medal, ""))) if not medal.is_empty() else "", int(day.gold)]

static func _go(home: Control, box: VBoxContainer) -> void:
	## The way down, or for a guest, the word that they are ready; how ready the party is; and
	## what this player pays at the shaft head, with the insurance on their haul.
	var lobby: Dictionary = home.lobby
	var me: Dictionary = lobby.members.get(home.local_id, {})
	var order: Array = lobby.get("order", [])
	if order.size() > 1:
		var ready_count: int = order.filter(func(id: Variant) -> bool:
			return str(id) == str(lobby.get("host", "p0")) or bool(lobby.members.get(id, {}).get("ready", false))).size()
		var summary := DeepUi.hbox(box, 8)
		DeepUi.stat(summary, "party", "A party of %d" % order.size(), DeepUi.PAPER, 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.pill(summary, "check", "%d of %d ready" % [ready_count, order.size()], DeepUi.GOOD if ready_count == order.size() else DeepUi.MUTED, 11)
	if not str(lobby.get("daily", "")).is_empty():
		_go_daily(home, box, me)
		return
	var who: String = str(DeepContent.character(str(home.profile.get("current_character", ""))).get("name", "you"))
	## The tier goes into the button's words: nobody sets out on one by accident.
	var tier: int = int(lobby.get("hazard", 0))
	if tier > 0:
		who = "%s · Hazard %d" % [who, tier]
	var insured: bool = bool(home.profile.get("outfit", {}).get("insure", false))
	var cost: int = DeepEconomy.departure(home.chosen_mine(), insured)
	var purse: int = int(home.profile.get("gold", 0))
	var short: Array = order.filter(func(id: Variant) -> bool: return home.member_short(lobby.members.get(id, {})))
	_empty_rail(home, box)
	if not home.is_host:
		var guest_row := DeepUi.hbox(box, 8)
		var ready := DeepUi.primary(guest_row, "check", "Unready" if bool(me.get("ready", false)) else "Ready as %s" % who,
			func() -> void: home.member_changed.emit({"ready": not bool(me.get("ready", false))}), 16, DeepUi.GOOD)
		if cost > 0 and not bool(me.get("ready", false)):
			DeepUi.priced(ready, str(cost))
		ready.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ready.disabled = home.status != "joined"
		_insurance_toggle(home, guest_row, insured)
		if purse < cost:
			## Wrapped like the host's warnings, so the long sentence never widens the column.
			_warn(box, "coin", "You can't pay the %d gold fare to %s. The host needs to pick a mine you can afford." % [cost, DeepContent.mine_name(home.chosen_mine())], Color("ffb04a"), "")
		return
	## Green, not the accent: the fare's coin sits on it, and a free mine looks the same.
	var go := DeepUi.primary(box, "descend", "Descend as %s" % who, func() -> void:
		home.depart_requested.emit(home.seed_value()), 20, DeepUi.GOOD)
	if cost > 0:
		DeepUi.priced(go, str(cost), 16)
	go.name = "Descend"
	go.tooltip_text = (("Taken from your purse at the shaft head: the fare%s." % (" and the insurance" if insured else "")) if cost > 0 else "The Quarry costs nothing to go down.") + " (Enter)"
	DeepUi.voice(go, "depart")
	go.custom_minimum_size.y = 54
	go.disabled = not home.can_start or bool(lobby.get("started", false))
	if not go.disabled:
		DeepUi.breathe(go, 0.82, 2.0)
	if short.size() == 1 and str(short[0]) == home.local_id and insured and purse >= DeepEconomy.fare(home.chosen_mine()):
		DeepUi.stat(box, "coin", "Your %d gold can't cover the insurance: turn it off to go down." % purse, DeepUi.BAD, 12)
	elif not short.is_empty():
		var names: Array = short.map(func(id: Variant) -> String: return "You" if str(id) == home.local_id else home.member_name(str(id)))
		_warn(box, "coin", "%s can't pay the fare to %s. Pick a mine everyone can afford." % [_who(names), DeepContent.mine_name(home.chosen_mine())], Color("ffb04a"), " and ".join(names), _faces(lobby, short))
	elif not _hazard_blocked(home).is_empty():
		var names: Array = _hazard_blocked(home).map(func(id: Variant) -> String: return "You" if str(id) == home.local_id else home.member_name(str(id)))
		_warn(box, "lock", "%s %s not opened %s on Hazard %d. Pick a mine everyone has." % [_who(names), "have" if names.size() > 1 or names[0] == "You" else "has",
			DeepContent.mine_name(home.chosen_mine()), tier], Color("ffb04a"), " and ".join(names), _faces(lobby, _hazard_blocked(home)))
	elif not home.can_start:
		DeepUi.stat(box, "hourglass", "Waiting for everyone to be ready.", DeepUi.MUTED, 12)
	var seed_row := DeepUi.hbox(box, 8)
	_insurance_toggle(home, seed_row, insured)
	DeepUi.gap(seed_row, 4)
	DeepUi.label(seed_row, "Seed", 12, DeepUi.DIM)
	var typed: String = home._seed.text if home._seed != null and is_instance_valid(home._seed) else ""
	## A seed sent from a past run (K5) is typed in for the player.
	if home.has_meta("seed_next"):
		typed = str(home.get_meta("seed_next"))
		home.remove_meta("seed_next")
	home._seed = LineEdit.new()
	home._seed.placeholder_text = "blank for a new one"
	home._seed.text = typed
	home._seed.custom_minimum_size = Vector2(120, 0)
	home._seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(home._seed)

static func _empty_rail(home: Control, box: VBoxContainer) -> void:
	## Every socket the delver has open is empty: their rail would do nothing down there.
	## Said in red over the way down, with the way to the socket picker beside it. Only for
	## the first mine: below it, every empty socket is offered a temporary stone at the shaft head.
	if home.chosen_mine() != DeepContent.starter_mine():
		return
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	var open: int = DeepProfile.open_sockets(home.profile, current)
	var rail: Array = DeepProfile.loadout(home.profile, current).rail
	if open <= 0 or rail.slice(0, open).any(func(s: Variant) -> bool: return s is Dictionary):
		return
	var line := DeepUi.hbox(box, 8)
	var said := DeepUi.stat(line, "gem", "No stones set: your rail will do nothing.", DeepUi.BAD, 12)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var words: Label = said.get_node("Value")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fix := DeepUi.icon_button(line, "gem", "Set stones", func() -> void: home.edit_loadout(current, 0), 13, DeepUi.BAD)
	fix.tooltip_text = "Open %s's sockets and set stones from your Vault." % str(DeepContent.character(current).get("name", "your delver"))
	fix.size_flags_vertical = Control.SIZE_SHRINK_CENTER

static func _hazard_blocked(home: Control) -> Array:
	## Everyone going down who has not opened the party's mine on the party's tier.
	var tier: int = int(home.lobby.get("hazard", 0))
	if tier <= 0:
		return []
	var out: Array = []
	for id in home.lobby.get("order", []):
		var member: Dictionary = home.lobby.get("members", {}).get(id, {})
		if bool(member.get("connected", true)) and not DeepSession.member_open_mines(member, tier).has(home.chosen_mine()):
			out.append(str(id))
	return out

static func _go_daily(home: Control, box: VBoxContainer, me: Dictionary) -> void:
	## The way down the day's seam: nothing to pay and nothing to insure. Whether it pays is
	## each player's own question, said beside the button.
	var date: String = str(home.lobby.get("daily", ""))
	var state: String = DeepEconomy.daily_state(home.profile, date)
	var best: Dictionary = DeepEconomy.daily_best(home.profile, date)
	var pays: String = {"fresh": "Your first dig today is paid in full.", "played": "Your best today is %d. This dig pays only what it adds." % int(best.score),
		"locked": "You have not beaten the Quarry: digging pays you nothing."}.get(state, "")
	if not home.is_host:
		var ready := DeepUi.primary(box, "check", "Unready" if bool(me.get("ready", false)) else "I'm ready", func() -> void: home.member_changed.emit({"ready": not bool(me.get("ready", false))}), 16, DeepUi.GOOD)
		ready.disabled = home.status != "joined"
		DeepUi.stat(box, "calendar", "The host is taking the party down today's seam. " + pays, DeepUi.MUTED, 12)
		return
	## Before the Quarry falls the seam is still open to dig, unpaid, as it is to a guest.
	var words: String = "Dig today's seam" if state == "fresh" else ("Dig it again" if state == "played" else "Dig today's seam (unpaid)")
	var go := DeepUi.primary(box, "calendar", words, func() -> void: home.depart_requested.emit(0), 20)
	go.name = "Descend"
	go.tooltip_text = "Down the day's seam as the delver it lends, with its stones and dice. Nothing of yours goes down, and nothing found comes home: it is scored and paid for. (Enter)"
	DeepUi.voice(go, "depart")
	go.custom_minimum_size.y = 54
	go.disabled = not home.can_start or bool(home.lobby.get("started", false))
	if not go.disabled:
		DeepUi.breathe(go, 0.82, 2.0)
	if not home.can_start:
		DeepUi.stat(box, "hourglass", "Waiting for everyone to be ready.", DeepUi.MUTED, 12)
	else:
		DeepUi.stat(box, "calendar", pays if state != "locked" else "You are paid from the day you beat the Quarry.", DeepUi.GOOD if state == "fresh" else DeepUi.MUTED, 12)

static func _insurance_toggle(home: Control, parent: Node, insured: bool) -> Button:
	## Insurance on the haul, remembered from one run to the next until turned off.
	var price: int = DeepEconomy.insurance(home.chosen_mine())
	var cover := DeepUi.icon_button(parent, "check" if insured else "split_shield", "Insured" if insured else "Insure",
		func() -> void: home.set_insured(not insured), 13, DeepUi.GOOD if insured else DeepUi.MUTED)
	cover.tooltip_text = "Insurance: if the dig is lost, every salvage die is thrown twice and the better throw kept. Paid at the shaft head, every run, until you turn it off."
	if insured:
		DeepUi.selected_style(cover, DeepUi.GOOD)
	elif int(home.profile.get("gold", 0)) < DeepEconomy.departure(home.chosen_mine(), true):
		cover.disabled = true
		## Added to what insurance does, not in place of it: the price alone explains nothing.
		cover.tooltip_text += "\nYou have %d gold: the fare down and the insurance together cost %d." % [int(home.profile.get("gold", 0)), DeepEconomy.departure(home.chosen_mine(), true)]
	## Last: the price tag widens whatever look the button ends up with.
	DeepUi.priced(cover, str(price))
	return cover

static func _who(names: Array) -> String:
	## One delver by name; several by count, their names in the warning's tooltip.
	return str(names[0]) if names.size() == 1 else "%d of you" % names.size()

static func _faces(lobby: Dictionary, ids: Array) -> Array:
	## The delvers the members named in a warning are going down as, each with the Birthstone
	## they wear: [character, stone].
	return ids.map(func(id: Variant) -> Array:
		var member: Dictionary = lobby.get("members", {}).get(id, {})
		return [str(member.get("character", DeepContent.starter_character())), Roster.member_stone(member)])

static func _warn(box: Node, glyph: String, text: String, color: Color, tooltip: String, faces: Array = []) -> void:
	## A warning about the party. It wraps under its mark rather than pushing the page wider.
	## The delvers it names sit after the mark, so two players called alike are told apart.
	var row := DeepUi.stat(box, glyph, text, color, 12, tooltip)
	for index in range(mini(faces.size(), 4)):
		var face := Roster.Portrait.new(str(faces[index][0]), Vector2(24, 24), false, false, false, faces[index][1])
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
		row.move_child(face, 1 + index)
	var words: Label = row.get_node("Value")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
