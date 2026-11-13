extends RefCounted
## You, on the phone (docs/PHONE_UI.md, board home-you, approved November 7, 2026): the player
## chip at the desk's top right becomes the You place at the foot of the rail. Its page is the
## ledger: the face and name on top with Settings at the right, the seven numbers in one row,
## then the showcase, the mines and the recent runs as three tabs.

const ProfilePage = preload("res://view/home/profile_page.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const MineMap = preload("res://view/home/mine_map.gd")
const Roster = preload("res://view/home/roster.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")

const TABS: Array = [["showcase", "star", "Showcase"], ["mines", "map", "Mines"], ["runs", "hourglass", "Recent runs"]]
## A conquest mark's edge, in points.
const MARK: float = 7.0

static func build(home: Control, content: VBoxContainer) -> void:
	var records: Dictionary = home.profile.get("records", {})
	var best_score: int = int(records.get("best", {}).get("score", -1))
	if best_score > int(home.profile.get("best_seen", -1)):
		home.profile.best_seen = best_score
		home.call_deferred("touch")
	_head(home, content)
	_numbers(home, content, records)
	var tab: String = str(home.get_meta("you_tab", "showcase"))
	var tabs := DeepUi.hbox(content, int(DeepUi.pt(3)))
	## A sideways flick over the page turns them too (view/ui/swipe.gd).
	tabs.set_meta("swipe_tabs", true)
	for entry in TABS:
		var key: String = str(entry[0])
		var b := DeepUi.tab_button(tabs, str(entry[1]), str(entry[2]), key == tab, func() -> void:
			home.set_meta("you_tab", key)
			home._render(), 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = DeepUi.pt(32)
	var body := DeepUi.vbox(content, int(DeepUi.pt(4)))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match tab:
		"mines": _mines(home, body)
		"runs": _runs(home, body)
		_: _showcase(home, body)

static func _head(home: Control, content: VBoxContainer) -> void:
	var row := DeepUi.hbox(content, int(DeepUi.pt(10)))
	var player_name: String = str(home.profile.get("name", DeepProfile.DEFAULT_NAME))
	var frame := DeepUi.card(row, Color(DeepUi.ACCENT, 0.6), int(DeepUi.pt(3)))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(HomeParts.Avatar.new(player_name, DeepUi.pt(34)))
	var names := DeepUi.vbox(row, 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := DeepUi.hbox(names, int(DeepUi.pt(8)))
	var title := DeepUi.title(line, player_name, 26, DeepUi.PAPER)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var font: Font = title.get_theme_font("font")
	title.custom_minimum_size.x = minf(font.get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x + 4.0, DeepUi.pt(200))
	var rename := DeepUi.icon_button(line, "contract", "Name", func() -> void: home.player_name_requested.emit(), 11, DeepUi.MUTED)
	rename.name = "Rename"
	rename.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rename.custom_minimum_size.y = DeepUi.pt(30)
	var history: Array = home.profile.get("history", [])
	var since: String = str(history[0].get("date", "")) if not history.is_empty() else ""
	var said := DeepUi.label(names, ("Delving since %s" % since if not since.is_empty() else "No runs yet") + " · %d of %d gems owned" % [home.profile.get("vault", {}).size(), DeepProfile.known_skills(home.profile).size()], 11, DeepUi.MUTED)
	## Cut short rather than pushing Settings off the page.
	said.clip_text = true
	said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	said.custom_minimum_size.x = DeepUi.pt(120)
	## Settings live here on the phone: the desk's gear in the corner has no place on the rail.
	var gear := DeepUi.icon_button(row, "gear", "Settings", func() -> void: home.settings_requested.emit(), 12, DeepUi.PAPER)
	gear.name = "Settings"
	DeepUi.ledger_button(gear, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 8)
	gear.custom_minimum_size.y = DeepUi.pt(36)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	home.enter(row)

static func _numbers(home: Control, content: VBoxContainer, records: Dictionary) -> void:
	## The seven numbers, in one row.
	var row := DeepUi.hbox(content, int(DeepUi.pt(4)))
	for entry in [["pick", "runs", "runs"], ["lift", "extractions", "extractions"], ["crown", "conquests", "conquests"], ["skull", "falls", "falls"],
			["flag", "commissions", "commissions"], ["contract", "contracts", "contracts"], ["calendar", "best_daily", "best daily"]]:
		var cell := DeepUi.vbox(row, 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := DeepUi.hbox(cell, int(DeepUi.pt(3)))
		value.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.icon(value, str(entry[0]), DeepUi.glyph_px(13), DeepUi.ACCENT)
		DeepUi.title(value, str(int(records.get(str(entry[1]), 0))), 18, DeepUi.PAPER)
		DeepUi.label(cell, str(entry[2]), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if str(entry[1]) == "best_daily":
			var bests: Array = records.get("daily_bests", []).duplicate()
			bests.reverse()
			var said: Array = ["Your best score on each day's seam:"]
			for day in bests.slice(0, 10):
				said.append("%s: %d (%d gold)" % [str(day.get("date", "")), int(day.get("score", 0)), int(day.get("gold", 0))])
			var text: String = "\n".join(said) if not bests.is_empty() else "No daily digs yet."
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			Tips.attach(cell, func() -> Control: return Plates.words("Best daily", text))
	home.enter(row, 0.03)

static func _showcase(home: Control, body: VBoxContainer) -> void:
	## Five kept stones in a row, each a plate as tall as the page lets it stand.
	var row := DeepUi.hbox(body, int(DeepUi.pt(8)))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stones: Array = DeepProfile.showcase(home.profile)
	if stones.is_empty():
		DeepUi.label(row, "Keep a stone to start the showcase. Your starred stones come first, then your best by grade; the party sees them too.", 12, DeepUi.DIM)
		return
	for index in range(stones.size()):
		var stone: Dictionary = stones[index]
		var grade: Dictionary = DeepStone.grade(stone)
		var tone: Color = DeepUi.tier_color(str(grade.tier))
		var plate := DeepUi.card(row, Color(tone, 0.55), int(DeepUi.pt(6)), Color(0.04, 0.09, 0.1, 0.92))
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.mouse_filter = Control.MOUSE_FILTER_STOP
		var column := DeepUi.vbox(plate, int(DeepUi.pt(2)))
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var picture := DeepUi.center(column)
		picture.custom_minimum_size.y = DeepUi.pt(80)
		if index == 0:
			picture.add_child(HomeParts.Showcase.new(stone, DeepUi.pt(80)))
		else:
			StoneCard.picture(picture, stone, DeepUi.pt(70))
		DeepUi.label(column, DeepUi.skill_name(stone), 13, DeepUi.color(DeepStone.color(stone)).lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(column, "%s · %d" % [str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), int(grade.score)], 12, tone, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.fit_label(column, "%d ct · %s · %s" % [int(stone.get("carat", 1)), DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.clarity_name(int(stone.get("clarity", 0)))], 11, DeepUi.MUTED, DeepUi.pt(90)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		## Its grade, part by part, on a hold.
		Tips.attach(plate, func() -> Control: return Plates.grade(stone), {"tone": tone})
		home.enter(plate, 0.04 * index)

static func _mines(home: Control, body: VBoxContainer) -> void:
	var card := DeepUi.card(body, DeepUi.LINE, int(DeepUi.pt(8)))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(card, int(DeepUi.pt(4)))
	## Conquests are kept by Birthstone (ProfilePage.StoneMarks): a column a delver, three marks
	## a mine, their faces over the columns. A hold on a column names its stones.
	var met: Array = DeepProfile.unlocked_characters(home.profile)
	var heads := DeepUi.hbox(box, int(DeepUi.pt(8)))
	DeepUi.label(heads, "Final bosses beaten, by Birthstone", 11, DeepUi.DIM).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ProfilePage.stone_heads(heads, met, DeepUi.pt(14), DeepUi.pt(MARK))
	for key in DeepContent.mines_in_order():
		var record: Dictionary = home.profile.get("mines", {}).get(str(key), {})
		var open: bool = bool(record.get("unlocked", false))
		var mine: Dictionary = DeepContent.mine(str(key))
		var tone: Color = Color(str(mine.get("palette", "c9a26b")))
		var row := DeepUi.hbox(box, int(DeepUi.pt(8)))
		var numeral := DeepUi.label(row, MineMap.numeral(str(key)), 12, tone if open else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		numeral.add_theme_font_override("font", DeepUi.caps_font())
		numeral.custom_minimum_size.x = DeepUi.pt(22)
		var named := DeepUi.label(row, DeepContent.mine_name(str(key)), 13, DeepUi.PAPER if open else DeepUi.DIM)
		named.custom_minimum_size.x = DeepUi.pt(120)
		if not open:
			DeepUi.stat(row, "lock", "sealed", DeepUi.DIM, 11)
			continue
		var bottom: int = DeepContent.mine_bottom(str(key))
		var deepest: int = int(record.get("deepest", 0))
		var meter := DeepUi.bar(row, DeepUi.pt(5), DeepUi.ACCENT, Color(DeepUi.LINE, 0.6))
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.set_values(float(deepest) / float(bottom) if bottom > 0 else clampf(float(deepest) / 64.0, 0.0, 1.0))
		var crowns: int = mine.get("warden_depths", []).size() + 1
		DeepUi.stat(row, "stairs", "%d%s" % [deepest, (" / %d" % bottom) if bottom > 0 else ""], DeepUi.INFO, 11)
		DeepUi.stat(row, "crown", "%d / %d" % [mini(record.get("wardens", []).size(), crowns), crowns] if bottom > 0 else str(record.get("wardens", []).size()), DeepUi.ACCENT, 11)
		DeepUi.stat(row, "pick", str(int(record.get("runs", 0))), DeepUi.MUTED, 11).custom_minimum_size.x = DeepUi.pt(34)
		ProfilePage.stone_marks(row, home.profile, met, str(key), DeepUi.pt(MARK))
	home.enter(card, 0.05)

static func _runs(home: Control, body: VBoxContainer) -> void:
	## Every run, newest first, in a list that scrolls.
	var history: Array = home.profile.get("history", []).duplicate()
	history.reverse()
	var card := DeepUi.card(body, DeepUi.LINE, int(DeepUi.pt(6)))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if history.is_empty():
		DeepUi.label(card, "No runs yet.", 12, DeepUi.MUTED)
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("may_scroll", true)
	card.add_child(scroll)
	var box := DeepUi.vbox(scroll, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var deepest_seen: int = 1
	for run in history:
		deepest_seen = maxi(deepest_seen, int(run.get("depth", 0)))
	var shown: int = 0
	for run in history:
		var outcome: String = str(run.get("outcome", ""))
		var daily: bool = bool(run.get("daily", false))
		var tone: Color = DeepUi.BAD if outcome == "fallen" else (DeepUi.ACCENT if outcome == "conquered" else DeepUi.GOOD)
		var panel := DeepUi.panel(box, Color(1, 1, 1, 0.025 if shown % 2 == 0 else 0.0), Color(0, 0, 0, 0), 6, int(DeepUi.pt(3)))
		var row := DeepUi.hbox(panel, int(DeepUi.pt(6)))
		DeepUi.icon(row, "calendar" if daily else {"fallen": "skull", "conquered": "crown"}.get(outcome, "lift"), DeepUi.glyph_px(12), DeepUi.INFO if daily else tone)
		DeepUi.label(row, "Daily dig" if daily else outcome.capitalize(), 12, DeepUi.INFO if daily else tone).custom_minimum_size.x = DeepUi.pt(70)
		DeepUi.label(row, str(run.get("date", "")), 11, DeepUi.DIM).custom_minimum_size.x = DeepUi.pt(70)
		var where := DeepUi.label(row, DeepContent.mine_name(str(run.get("deepest_mine", run.get("mine", ""))) if daily else str(run.get("mine", ""))), 12, DeepUi.PAPER)
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		where.clip_text = true
		where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var character: String = str(run.get("character", ""))
		if not DeepContent.character(character).is_empty():
			## Who dug it, and in which Birthstone when it was not their first: "Ardor · Rampart".
			var stone: Dictionary = Roster.record_stone(run)
			row.add_child(Roster.Portrait.new(character, Vector2(DeepUi.pt(18), DeepUi.pt(18)), false, false, false, stone))
			var who := DeepUi.label(row, Roster.named(character, stone, false), 11, DeepUi.MUTED if Roster.is_first(character, stone) else Roster.stone_tone(stone))
			who.name = "DugAs"
			who.custom_minimum_size.x = DeepUi.pt(130)
			who.clip_text = true
			who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var depth := DeepUi.bar(row, DeepUi.pt(4), DeepUi.INFO, Color(DeepUi.LINE, 0.5))
		depth.custom_minimum_size = Vector2(DeepUi.pt(60), DeepUi.pt(4))
		depth.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		depth.set_values(float(int(run.get("depth", 0))) / float(deepest_seen))
		DeepUi.label(row, str(int(run.get("depth", 0))), 12, DeepUi.INFO).custom_minimum_size.x = DeepUi.pt(20)
		if daily:
			DeepUi.stat(row, "star", str(int(run.get("score", 0))), DeepUi.PAPER, 11)
		else:
			DeepUi.stat(row, "gem", str(int(run.get("stones", 0))), DeepUi.ACCENT, 11)
		shown += 1
	home.enter(card, 0.05)
