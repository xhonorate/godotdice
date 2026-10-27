extends RefCounted
## The player's own page, opened from the chip with their name: who they are and how long
## they have dug, their totals, the showcase (their best five stones, which the party can see
## too), how deep they have been in every mine, and their recent runs.

const HomeParts = preload("res://view/home/home_parts.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const MineMap = preload("res://view/home/mine_map.gd")
const Roster = preload("res://view/home/roster.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")

const RUNS_PAGE: int = 9

static func build(home: Control, content: VBoxContainer) -> void:
	var records: Dictionary = home.profile.get("records", {})
	var best_score: int = int(records.get("best", {}).get("score", -1))
	if best_score > int(home.profile.get("best_seen", -1)):
		## Looking is enough: the chip's pip for a new record goes once the page is opened.
		home.profile.best_seen = best_score
		home.call_deferred("touch")
	_head(home, content, records)
	_showcase(home, content)
	var columns := DeepUi.hbox(content, 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mines(home, columns)
	_runs(home, columns)

static func _head(home: Control, content: VBoxContainer, records: Dictionary) -> void:
	var row := DeepUi.hbox(content, 18)
	var player_name: String = str(home.profile.get("name", DeepProfile.DEFAULT_NAME))
	row.add_child(HomeParts.Avatar.new(player_name, 76))
	var names := DeepUi.vbox(row, 2)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := DeepUi.hbox(names, 10)
	## A long name is cut short with an ellipsis rather than pushing the records off the page.
	var title := DeepUi.title(line, player_name, 30, DeepUi.PAPER)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var font: Font = title.get_theme_font("font")
	title.custom_minimum_size.x = minf(font.get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 4.0, 480.0)
	title.tooltip_text = player_name
	var rename := DeepUi.icon_button(line, "contract", "Change name", func() -> void: home.player_name_requested.emit(), 12, DeepUi.MUTED)
	rename.name = "Rename"
	rename.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var history: Array = home.profile.get("history", [])
	var since: String = str(history[0].get("date", "")) if not history.is_empty() else ""
	DeepUi.label(names, ("Delving since %s" % since if not since.is_empty() else "No runs yet") + " · %d of %d gems owned" % [home.profile.get("vault", {}).size(), DeepProfile.known_skills(home.profile).size()], 13, DeepUi.MUTED)
	for entry in [["pick", "runs", "runs"], ["lift", "extractions", "extractions"], ["crown", "conquests", "conquests"], ["skull", "falls", "falls"],
			["flag", "commissions", "commissions"], ["contract", "contracts", "contracts"], ["calendar", "best_daily", "best daily"]]:
		var tile := DeepUi.vbox(row, 0)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.custom_minimum_size.x = 82
		var value := DeepUi.hbox(tile, 6)
		value.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.icon(value, str(entry[0]), 18, DeepUi.ACCENT)
		DeepUi.title(value, str(int(records.get(str(entry[1]), 0))), 24, DeepUi.PAPER)
		DeepUi.label(tile, str(entry[2]), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if str(entry[1]) == "best_daily":
			var bests: Array = records.get("daily_bests", []).duplicate()
			bests.reverse()
			var said: Array = ["Your best score on each day's seam:"]
			for day in bests.slice(0, 10):
				said.append("%s: %d (%d gold)" % [str(day.get("date", "")), int(day.get("score", 0)), int(day.get("gold", 0))])
			tile.tooltip_text = "\n".join(said) if not bests.is_empty() else "No daily digs yet."
			tile.mouse_filter = Control.MOUSE_FILTER_STOP
	home.enter(row)

static func _showcase(home: Control, content: VBoxContainer) -> void:
	## Five kept stones, the starred ones first, then the best: what the party sees when they look.
	var card := DeepUi.card(content, Color(DeepUi.ACCENT, 0.35), 14)
	var box := DeepUi.vbox(card, 10)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "star", "Showcase").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(head, "Your starred stones first, then your best by grade. The party sees them too.", 12, DeepUi.DIM)
	var row := DeepUi.hbox(box, 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var stones: Array = DeepProfile.showcase(home.profile)
	if stones.is_empty():
		DeepUi.label(row, "Keep a stone to start the showcase.", 14, DeepUi.DIM)
	for index in range(stones.size()):
		var stone: Dictionary = stones[index]
		var grade: Dictionary = DeepStone.grade(stone)
		var tone: Color = DeepUi.tier_color(str(grade.tier))
		var plate := DeepUi.card(row, Color(tone, 0.55), 10, Color(0.04, 0.09, 0.1, 0.92))
		plate.custom_minimum_size = Vector2(230, 0)
		plate.mouse_filter = Control.MOUSE_FILTER_STOP
		var column := DeepUi.vbox(plate, 4)
		var picture := DeepUi.center(column)
		## Every plate's picture is as tall as the first one's lamp, so names and grades line up.
		picture.custom_minimum_size.y = 120.0
		if index == 0:
			picture.add_child(HomeParts.Showcase.new(stone, 120))
		else:
			StoneCard.picture(picture, stone, 110.0)
		DeepUi.label(column, DeepUi.skill_name(stone), 16, DeepUi.color(DeepStone.color(stone)).lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(column, "%s · %d" % [str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier)), int(grade.score)], 13, tone, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(column, "%d ct · %s · %s" % [int(stone.get("carat", 1)), DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.clarity_name(int(stone.get("clarity", 0)))], 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		plate.mouse_entered.connect(func() -> void: home.hover_stone(plate, stone, {}))
		## Its grade, part by part: why a heavy Perfect Clear stone can sit under a lighter Included one.
		Tips.attach(plate, func() -> Control: return Plates.grade(stone), {"tone": tone, "below": true})
		home.enter(plate, 0.04 * index)
	home.enter(card, 0.05)

static func _mines(home: Control, columns: HBoxContainer) -> void:
	var card := DeepUi.card(columns, DeepUi.LINE, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(card, 8)
	DeepUi.section(box, "map", "Mines")
	for key in DeepContent.mines_in_order():
		var record: Dictionary = home.profile.get("mines", {}).get(str(key), {})
		var open: bool = bool(record.get("unlocked", false))
		var mine: Dictionary = DeepContent.mine(str(key))
		var tone: Color = Color(str(mine.get("palette", "c9a26b")))
		var row := DeepUi.hbox(box, 10)
		var numeral := DeepUi.label(row, MineMap.numeral(str(key)), 14, tone if open else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		numeral.add_theme_font_override("font", DeepUi.caps_font())
		numeral.custom_minimum_size.x = 30
		var named := DeepUi.label(row, DeepContent.mine_name(str(key)), 14, DeepUi.PAPER if open else DeepUi.DIM)
		named.custom_minimum_size.x = 150
		if not open:
			DeepUi.stat(row, "lock", "sealed", DeepUi.DIM, 12)
			continue
		var bottom: int = DeepContent.mine_bottom(str(key))
		var deepest: int = int(record.get("deepest", 0))
		var meter := DeepUi.bar(row, 8.0, DeepUi.ACCENT, Color(DeepUi.LINE, 0.6))
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		meter.set_values(float(deepest) / float(bottom) if bottom > 0 else clampf(float(deepest) / 64.0, 0.0, 1.0))
		var crowns: int = mine.get("warden_depths", []).size() + 1
		DeepUi.stat(row, "stairs", "%d%s" % [deepest, (" / %d" % bottom) if bottom > 0 else ""], DeepUi.INFO, 12, "Deepest reached")
		DeepUi.stat(row, "crown", "%d / %d" % [mini(record.get("wardens", []).size(), crowns), crowns] if bottom > 0 else str(record.get("wardens", []).size()), DeepUi.ACCENT, 12, "Wardens and the final boss beaten")
		DeepUi.stat(row, "pick", str(int(record.get("runs", 0))), DeepUi.MUTED, 12, "Runs")
	home.enter(card, 0.1)

static func _runs(home: Control, columns: HBoxContainer) -> void:
	var card := DeepUi.card(columns, DeepUi.LINE, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(card, 4)
	var head := DeepUi.hbox(box, 8)
	DeepUi.section(head, "hourglass", "Recent runs").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var history: Array = home.profile.get("history", []).duplicate()
	history.reverse()
	if history.is_empty():
		DeepUi.label(box, "No runs yet.", 13, DeepUi.MUTED)
	var deepest_seen: int = 1
	for run in history:
		deepest_seen = maxi(deepest_seen, int(run.get("depth", 0)))
	var shown: int = 0
	for run in home.paged(head, "ledger", history, RUNS_PAGE):
		var outcome: String = str(run.get("outcome", ""))
		var daily: bool = bool(run.get("daily", false))
		var tone: Color = DeepUi.BAD if outcome == "fallen" else (DeepUi.ACCENT if outcome == "conquered" else DeepUi.GOOD)
		var panel := DeepUi.panel(box, Color(1, 1, 1, 0.025 if shown % 2 == 0 else 0.0), Color(0, 0, 0, 0), 6, 5)
		var row := DeepUi.hbox(panel, 10)
		DeepUi.icon(row, "calendar" if daily else {"fallen": "skull", "conquered": "crown"}.get(outcome, "lift"), 16, DeepUi.INFO if daily else tone, outcome.capitalize())
		DeepUi.label(row, "Daily dig" if daily else outcome.capitalize(), 13, DeepUi.INFO if daily else tone).custom_minimum_size.x = 84
		DeepUi.label(row, str(run.get("date", "")), 12, DeepUi.DIM).custom_minimum_size.x = 84
		var where := DeepUi.label(row, DeepContent.mine_name(str(run.get("deepest_mine", run.get("mine", ""))) if daily else str(run.get("mine", ""))), 13, DeepUi.PAPER)
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var character: String = str(run.get("character", ""))
		if not DeepContent.character(character).is_empty():
			row.add_child(Roster.Portrait.new(character, Vector2(22, 22)))
		var depth := DeepUi.bar(row, 6.0, DeepUi.INFO, Color(DeepUi.LINE, 0.5))
		depth.custom_minimum_size = Vector2(80, 6)
		depth.size_flags_horizontal = Control.SIZE_SHRINK_END
		depth.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		depth.set_values(float(int(run.get("depth", 0))) / float(deepest_seen))
		DeepUi.label(row, str(int(run.get("depth", 0))), 13, DeepUi.INFO).custom_minimum_size.x = 26
		if daily:
			DeepUi.stat(row, "star", str(int(run.get("score", 0))), DeepUi.PAPER, 12, "Score")
		else:
			DeepUi.stat(row, "gem", str(int(run.get("stones", 0))), DeepUi.ACCENT, 12, "Stones brought home")
		shown += 1
	home.enter(card, 0.12)
