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

const DAILY_KIND_WORDS: Dictionary = {"rail": "Rail rule", "hazard": "Hazard", "blessing": "Blessing", "twist": "Twist"}
const SIDE_WIDTH: float = 450.0

static func build(home: Control, content: VBoxContainer) -> void:
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
	var side := DeepUi.vbox(columns, 12)
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
		DeepUi.pill(facts, "gem", "up to %d ct" % int(band.cap), DeepUi.ACCENT_HI if lift > 0 else DeepUi.PAPER, 12, "Stones usually up to %d carats, never over %d.%s" % [int(band.soft), int(band.cap),
			(" Hazard %d lifts both by %d." % [tier, lift]) if lift > 0 else ""])
	if deeper:
		DeepUi.pill(facts, "ore", "start with %d pyrite" % int(mine.get("start_pyrite", 0)), DeepUi.ORE, 12,
			"Starting here costs a fare of %d gold, paid by each delver at the shaft head. Each starts with this much pyrite, and every socket not bought is offered three temporary stones that shatter when the run ends." % DeepEconomy.fare(chosen_key))
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
		var portrait := Roster.Portrait.new(str(key), Vector2(48, 48), not unlocked, str(key) == current, false)
		portrait.tooltip_text = DeepContent.character_title(str(key)) if unlocked else "Locked. " + Roster.unlock_hint(str(key)) + "."
		faces.add_child(portrait)
		if unlocked:
			portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			portrait.tooltip_text += "\nRight-click for their page."
			var picked: String = str(key)
			portrait.gui_input.connect(func(event: InputEvent) -> void:
				if not event is InputEventMouseButton or not event.pressed:
					return
				if event.button_index == MOUSE_BUTTON_RIGHT:
					DeepAudio.play("ui_tap")
					home._roster_pick = picked
					home._roster_view = "dossier"
					home._bench_socket = -1
					home.open("delvers", true)
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
	## The Birthstone in its own color, as the dossier wears it, not the info blue (Blue is guard).
	var birth: Dictionary = DeepStone.birthstone(current)
	var birth_tone: Color = GemMesh.tint(birth).lightened(0.3) if not birth.is_empty() else DeepUi.INFO
	DeepUi.pill(pills, "gem", str(character.get("birthstone", {}).get("name", "Birthstone")), birth_tone, 11, str(character.get("birthstone", {}).get("text", "")))
	var loadout: Dictionary = DeepProfile.loadout(home.profile, current)
	var rail := DeepUi.hbox(box, 6)
	home.socket_strip(rail, current, loadout, 44.0, false, func(index: int) -> void: home.edit_loadout(current, index))
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
	if empty > 0:
		DeepUi.stat(dice, "gem", "%s empty" % DeepUi.plural(empty, "socket"), DeepUi.ACCENT, 12)
	else:
		DeepUi.label(dice, "Click a socket to change it", 12, DeepUi.DIM)
	home.enter(wear, 0.05)

static func _daily_tone(kind: String) -> Color:
	match kind:
		"hazard": return DeepUi.BAD
		"blessing": return DeepUi.GOOD
		"twist": return Color("c58bff")
	return DeepUi.INFO

static func _daily_view(home: Control, side: VBoxContainer) -> void:
	## The day's seam: the same for everyone on this build today. Its four cards, how it is
	## scored and paid, where this player stands today, and the delver it lends the party.
	var date: String = str(home.lobby.get("daily", ""))
	if date.is_empty():
		date = DeepEconomy.today()
	var plan: Dictionary = DeepEconomy.daily_plan(date)
	var mine: Dictionary = DeepContent.mine(str(plan.mine))
	var seam := DeepUi.card(side, Color(DeepUi.ACCENT, 0.4), 14)
	var box := DeepUi.vbox(seam, 6)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "calendar", "The daily dig").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left: int = DeepEconomy.seconds_to_tomorrow()
	DeepUi.stat(head, "hourglass", "%dh %02dm left" % [left / 3600, (left % 3600) / 60], DeepUi.MUTED, 12, "A new seam opens every day at midnight UTC.")
	var title := DeepUi.title(box, "%s, and on down" % str(mine.get("name", plan.mine)), 22, DeepUi.PAPER)
	title.tooltip_text = "It starts at the top of the Quarry and goes on through every mine, as deep as you want to go."
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	DeepUi.label(box, "The same seam for everyone today.", 12, DeepUi.MUTED)
	for key in [str(plan.rail)] + plan.get("mods", []):
		var mod: Dictionary = DeepEconomy.daily_mod(str(key))
		var kind: String = str(mod.get("kind", "hazard"))
		var hue: Color = _daily_tone(kind)
		var line := DeepUi.hbox(box, 8)
		DeepUi.icon(line, str(mod.get("glyph", "spark")), 20, hue, str(DAILY_KIND_WORDS.get(kind, ""))).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var words := DeepUi.vbox(line, 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name: String = str(mod.get("name", key))
		if str(key) == "DROUGHT" and plan.has("drought"):
			name = "%s: no %s" % [name, str(DeepContent.color(str(plan.drought)).get("name", plan.drought))]
		if str(key) == "BORROWED_BIRTHSTONE" and plan.has("birthstone"):
			name = "%s: %s's" % [name, DeepContent.character_title(str(plan.birthstone)).get_slice(",", 0)]
		var title_line := DeepUi.hbox(words, 6)
		DeepUi.label(title_line, name, 14, hue.lightened(0.1))
		DeepUi.label(title_line, str(DAILY_KIND_WORDS.get(kind, "")), 11, DeepUi.DIM)
		DeepUi.wrap(words, str(mod.get("text", "")), 12, DeepUi.MUTED)
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
	home.enter(seam)
	var seat: int = maxi(0, home.lobby.get("order", []).find(home.local_id))
	var character: String = DeepEconomy.daily_lapidary(plan)
	var lent := DeepUi.card(side, DeepUi.LINE, 14)
	var lent_box := DeepUi.vbox(lent, 8)
	DeepUi.section(lent_box, "person", "Lent for the day")
	var row := DeepUi.hbox(lent_box, 12)
	row.add_child(Roster.Portrait.new(character, Vector2(60, 60)))
	var facts := DeepUi.vbox(row, 2)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.title(facts, DeepContent.character_title(character), 18, DeepUi.PAPER)
	DeepUi.wrap(facts, "The whole party goes down as this delver, with the stones and dice the day lends. Nothing of yours goes down.", 12, DeepUi.MUTED)
	var rail := DeepUi.hbox(lent_box, 6)
	var stones: Array = DeepEconomy.daily_rail(plan, character, seat)
	var sockets: Array = DeepContent.character(character).get("sockets", [])
	for index in range(sockets.size()):
		var stone: Variant = stones[index] if index < stones.size() else null
		home.kit_socket(rail, str(sockets[index]), stone if stone is Dictionary else {}, 40.0)
	var carried: String = str(plan.get("birthstone", character)) if plan.get("mods", []).has("BORROWED_BIRTHSTONE") else character
	home.kit_socket(rail, "BIRTHSTONE", DeepStone.birthstone(carried), 40.0)
	home.enter(lent, 0.05)

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
	## The delvers the members named in a warning are going down as.
	return ids.map(func(id: Variant) -> String: return str(lobby.get("members", {}).get(id, {}).get("character", DeepContent.starter_character())))

static func _warn(box: Node, glyph: String, text: String, color: Color, tooltip: String, faces: Array = []) -> void:
	## A warning about the party. It wraps under its mark rather than pushing the page wider.
	## The delvers it names sit after the mark, so two players called alike are told apart.
	var row := DeepUi.stat(box, glyph, text, color, 12, tooltip)
	for index in range(mini(faces.size(), 4)):
		var face := Roster.Portrait.new(str(faces[index]), Vector2(24, 24))
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
		row.move_child(face, 1 + index)
	var words: Label = row.get_node("Value")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
