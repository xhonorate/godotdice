## The sheet a mine's final boss leaves behind (Inspector.conquest): what the kill opened, as
## pills under the title; the mines from the workshop down, the party at the bottom of this one
## with the lift cable running up from it and the way on running down; and beside them the mine
## below: the skills first found there, the creatures waiting in it, and what going on risks.
## The two ways out of the hall stand under the sheet.
##
## `view` is drawn from the run and the lapidary's profile (descent_screen._show_conquest):
##   {mine, next, tier, depth, boss, opened, unlocked, purse, records, met, joined}
## `records` are the mines' records on the run's Hazard tier, `met` the creatures of the mine
## below already met, `joined` the delvers already at the workshop.

const StoneCard = preload("res://view/gems/stone_card.gd")
const GemIcons = preload("res://view/gems/gem_icons.gd")

const NUMERALS: Array = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
const PORTRAITS: String = "res://view/creatures/portraits/"
## A creature not met yet, as the bestiary draws one: its shape and nothing else.
const UNSEEN := Color(0.02, 0.03, 0.07, 0.92)
## A delver not at the workshop yet: their face, gone dark.
const UNMET_FACE := Color(0.2, 0.24, 0.36)
## The map stands where the inspected thing would; the page beside it is the sheet's own.
const MAP_SIZE := Vector2(400, 548)
const PAGE_WIDTH: float = 600.0
## The map's rows: the workshop's, the mine the party stands in, the mine below, every other.
const ROW_TOP: float = 40.0
const ROW_HERE: float = 86.0
const ROW_NEXT: float = 126.0
const ROW_OTHER: float = 49.0
## Where the rows' words start, leaving the strip down their left edge to the cable.
const INDENT: int = 58
const FLAVOR := Color("b4bfd9")

static func numeral(key: String) -> String:
	if DeepContent.is_endless(key):
		return "∞"
	var tier: int = DeepContent.mine_tier(key)
	return str(NUMERALS[tier - 1]) if tier >= 1 and tier <= NUMERALS.size() else str(tier)

static func tone_of(key: String) -> Color:
	return Color(str(DeepContent.mine(key).get("palette", "8a96b6")))

static func subtitle(view: Dictionary) -> String:
	## "The Drill is dead · 1 of 6 mines beaten", counted on the run's Hazard tier.
	var records: Dictionary = view.get("records", {})
	var beaten: int = 0
	var bottoms: int = 0
	for key in DeepContent.mines_in_order():
		if DeepContent.is_endless(str(key)):
			continue
		bottoms += 1
		if bool(records.get(str(key), {}).get("boss", false)) or str(key) == str(view.get("mine", "")):
			beaten += 1
	return "%s is dead · %d of %d mines beaten" % [str(view.get("boss", "The boss")), beaten, bottoms]

# --- under the title ---------------------------------------------------------------------------

static func header(view: Dictionary, column: Control) -> void:
	## What the kill opened, one pill each, kept whichever way the party goes: the mine below,
	## a Hazard tier, a delver, the first conquest's gold. A boss beaten before opens nothing.
	var row := DeepUi.hbox(column, 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var tier: int = int(view.get("tier", 0))
	for entry in view.get("unlocked", []):
		if entry.has("mine"):
			var opened: String = str(entry.mine)
			DeepUi.pill(row, "lock_open", "%s is open%s" % [DeepContent.mine_name(opened), " on Hazard %d" % tier if tier > 0 else ""], tone_of(opened).lightened(0.3), 15)
	for entry in view.get("unlocked", []):
		if entry.has("tier"):
			DeepUi.pill(row, "skull", "Hazard %d is open" % int(entry.tier), DeepUi.BAD, 15)
	for entry in view.get("unlocked", []):
		if entry.has("character"):
			var who: String = str(entry.character)
			_face_pill(row, who, "%s joined the workshop" % str(DeepContent.character(who).get("name", who)), DeepUi.TRADE, 15)
	if int(view.get("purse", 0)) > 0:
		DeepUi.pill(row, "coin", "+%d gold, fall or ride" % int(view.purse), DeepUi.ACCENT_HI, 15,
			"The first conquest's purse waits at the workshop, whether the party rides up or falls.")
	if row.get_child_count() == 0:
		DeepUi.pill(row, "crown", "Beaten before · nothing new opened this time", DeepUi.MUTED, 15)

static func _face_pill(parent: Node, character_key: String, text: String, tone: Color, size: int) -> PanelContainer:
	## A pill whose mark is a delver's face, cut like every other pill.
	var box := PanelContainer.new()
	var style := DeepUi.facet_ends(box, DeepUi.flat(Color(tone, 0.12), DeepUi.SLATE_LOW.lerp(tone, 0.45), 20, 3))
	style.content_margin_left = 6
	style.content_margin_right = 11
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(box)
	var line := DeepUi.hbox(box, 7)
	_face(line, character_key, 24.0, Color.WHITE)
	DeepUi.label(line, text, size, tone)
	return box

static func _face(parent: Node, character_key: String, edge: float, tint: Color) -> Control:
	var path: String = "res://view/home/delvers/%s/idle.png" % character_key.to_lower()
	if not ResourceLoader.exists(path):
		return DeepUi.icon(parent, "person", edge, tint)
	var face := TextureRect.new()
	face.texture = load(path)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.custom_minimum_size = Vector2(edge, edge)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.self_modulate = tint
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(face)
	return face

# --- the map -----------------------------------------------------------------------------------

static func map(stage: Control, view: Dictionary) -> void:
	## Every mine from the workshop down. The mine the party stands in and the one below are
	## drawn tall; the rest are a line each, beaten, open or sealed on this Hazard tier.
	var here_key: String = str(view.get("mine", ""))
	var next_key: String = str(view.get("next", ""))
	var records: Dictionary = view.get("records", {})
	var rows := DeepUi.vbox(stage, 6)
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := _row(rows, ROW_TOP, Color(0, 0, 0, 0))
	var heading := DeepUi.heading(top.get_child(0), "The workshop", 14, DeepUi.PAPER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.pill(top.get_child(0), "ore", "%d to ride up" % int(view.get("fare", 0)), DeepUi.ORE, 13,
		"What the winch wants to haul the party up from here.").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var here_row: Control = null
	var next_row: Control = null
	for key in DeepContent.mines_in_order():
		var mine_key: String = str(key)
		var record: Dictionary = records.get(mine_key, {})
		var tone: Color = tone_of(mine_key)
		var named: String = "%s · %s" % [numeral(mine_key), DeepContent.mine_name(mine_key)]
		if mine_key == here_key:
			here_row = _row(rows, ROW_HERE, Color(tone, 0.2))
			var line: HBoxContainer = here_row.get_child(0)
			var words := _words(line)
			_caps(words, named, 17, tone.lightened(0.45))
			_caps(words, "You are here · depth %d" % int(view.get("depth", 0)), 12, DeepUi.ACCENT_HI)
			DeepUi.pill(line, "crown", "Conquered", DeepUi.ACCENT_HI, 13).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elif mine_key == next_key:
			next_row = _row(rows, ROW_NEXT, Color(tone, 0.24))
			var line: HBoxContainer = next_row.get_child(0)
			var words := _words(line)
			_caps(words, named, 17, tone.lightened(0.55))
			var bottom: int = DeepContent.mine_bottom(mine_key)
			DeepUi.label(words, "%d depths" % bottom if bottom > 0 else "It does not end", 13, tone.lightened(0.3))
			var fresh: bool = str(view.get("opened", "")) == mine_key
			DeepUi.pill(line, "lock_open", "Just opened" if fresh else "Open", DeepUi.GOOD if fresh else tone.lightened(0.3), 13).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			var beaten: bool = bool(record.get("boss", false))
			var open: bool = bool(record.get("unlocked", false))
			var row := _row(rows, ROW_OTHER, Color(tone, 0.12 if open else 0.07))
			var line: HBoxContainer = row.get_child(0)
			var words := _words(line)
			_caps(words, named, 14, tone.lightened(0.2) if open else tone.darkened(0.4))
			if beaten:
				DeepUi.icon(line, "crown", 17, DeepUi.ACCENT, "Conquered").size_flags_vertical = Control.SIZE_SHRINK_CENTER
			elif open:
				DeepUi.icon(line, "lock_open", 17, tone.lightened(0.2), "Open").size_flags_vertical = Control.SIZE_SHRINK_CENTER
			else:
				DeepUi.icon(line, "lock", 16, DeepUi.DIM, "Sealed").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if here_row == null:
		return
	var wire := Wire.new(rows, top, here_row, next_row)
	wire.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(wire)

static func _row(parent: Node, height: float, bg: Color) -> PanelContainer:
	## One band of the map: a faceted strip in its mine's color, its words starting clear of
	## the cable. Its first child is the row its words and its mark go in.
	var box := PanelContainer.new()
	var style := DeepUi.flat(bg, Color(0, 0, 0, 0), 10, 0)
	style.content_margin_left = INDENT
	style.content_margin_right = 14
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size.y = height
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var line := DeepUi.hbox(box, 10)
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	return box

static func _words(line: HBoxContainer) -> VBoxContainer:
	var words := DeepUi.vbox(line, 3)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return words

static func _caps(parent: Node, text: String, size: int, color: Color) -> Label:
	## A name in the small-capitals face, at any size.
	var l := DeepUi.label(parent, text, size, color)
	l.add_theme_font_override("font", DeepUi.caps_font())
	return l

class Wire extends Control:
	## The lift's cable up from the party to the workshop, the party's mark at the bottom of
	## the mine it stands in, and the way on dashed down into the mine below. Laid over the
	## map's rows and read off where they were laid out.
	var workshop_row: Control
	var here_row: Control
	var next_row: Control

	func _init(rows: Control, workshop: Control, here: Control, next: Control) -> void:
		workshop_row = workshop
		here_row = here
		next_row = next
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.sort_children.connect(queue_redraw)

	func _draw() -> void:
		var x: float = 28.0
		var lift_at: float = workshop_row.position.y + workshop_row.size.y * 0.5
		var mark_at: float = here_row.position.y + here_row.size.y + 3.0
		draw_line(Vector2(x, lift_at + 14.0), Vector2(x, mark_at - 16.0), DeepUi.GOOD, 3.0)
		draw_texture_rect(GemIcons.texture("lift", 64), Rect2(Vector2(x - 14.0, lift_at - 14.0), Vector2(28, 28)), false, DeepUi.GOOD)
		if next_row != null:
			var down_at: float = next_row.position.y + next_row.size.y * 0.5
			draw_dashed_line(Vector2(x, mark_at + 18.0), Vector2(x, down_at - 12.0), DeepUi.ACCENT, 3.0, 8.0)
			draw_texture_rect(GemIcons.texture("descend", 64), Rect2(Vector2(x - 12.0, down_at - 12.0), Vector2(24, 24)), false, DeepUi.ACCENT)
		var glow: Texture2D = DeepUi.glow_texture()
		draw_texture_rect(glow, Rect2(Vector2(x - 34.0, mark_at - 34.0), Vector2(68, 68)), false, Color(DeepUi.ACCENT_HI, 0.45))
		draw_circle(Vector2(x, mark_at), 15.0, Color("0b0e14"))
		draw_arc(Vector2(x, mark_at), 15.0, 0.0, TAU, 40, DeepUi.ACCENT_HI, 2.0, true)
		draw_circle(Vector2(x, mark_at), 6.0, DeepUi.ACCENT_HI)

# --- the mine below ----------------------------------------------------------------------------

static func below(page: VBoxContainer, view: Dictionary) -> void:
	## The mine the party would dig into: its name and its words, the skills first found in its
	## rock (with how big its stones grow), the creatures it keeps (with how much harder they
	## are than here), who its boss would bring to the workshop, and what is risked going on.
	page.add_theme_constant_override("separation", 0)
	var key: String = str(view.get("next", ""))
	if key.is_empty():
		DeepUi.wrap(page, "There is nowhere further down. Ride the lift home.", 16, DeepUi.PAPER).custom_minimum_size.x = PAGE_WIDTH
		return
	var mine: Dictionary = DeepContent.mine(key)
	var here: Dictionary = DeepContent.mine(str(view.get("mine", "")))
	var tone: Color = tone_of(key)
	var tier: int = int(view.get("tier", 0))
	var fresh: bool = str(view.get("opened", "")) == key
	var where: String = "Mine %s" % numeral(key) if not DeepContent.is_endless(key) else "it does not end"
	_caps(page, ("Now open · %s" if fresh else "Below you · %s") % where, 13, tone.lightened(0.35))
	DeepUi.gap(page, 4)
	_caps(page, DeepContent.mine_name(key), 32, DeepUi.PAPER)
	DeepUi.gap(page, 4)
	DeepUi.wrap(page, str(mine.get("text", "")), 16, FLAVOR).custom_minimum_size.x = PAGE_WIDTH
	DeepUi.gap(page, 16)
	_skills(page, mine, here, tier)
	DeepUi.gap(page, 16)
	_creatures(page, key, mine, here, view.get("met", []))
	var after: String = str(mine.get("next", ""))
	var lapidary: String = str(DeepContent.mine(after).get("lapidary", "")) if not after.is_empty() else ""
	if not lapidary.is_empty() and not view.get("joined", []).has(lapidary):
		DeepUi.gap(page, 10)
		var line := DeepUi.hbox(page, 5)
		_face(line, lapidary, 26.0, UNMET_FACE)
		DeepUi.gap(line, 3)
		DeepUi.label(line, "Beat its boss and", 14, DeepUi.MUTED)
		DeepUi.label(line, str(DeepContent.character(lapidary).get("name", lapidary)), 14, DeepUi.TRADE)
		DeepUi.label(line, "joins the workshop.", 14, DeepUi.MUTED)
	DeepUi.gap(page, 8)
	var warning := DeepUi.hbox(page, 8)
	DeepUi.gap(warning, 2)
	DeepUi.icon(warning, "skull", 16, DeepUi.BAD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.label(warning, "You carry your current bag with you. Fall and risk losing everything.", 14, DeepUi.BAD.lightened(0.2))

static func _skills(page: VBoxContainer, mine: Dictionary, here: Dictionary, tier: int) -> void:
	## The mine's own batch: every skill whose rock is first found here, by name and rarity.
	var head := DeepUi.section(page, "gem", "First found here", DeepUi.ACCENT, 13)
	var band: Dictionary = DeepForge.carat_band(DeepForge.at_hazard(mine, tier), 1)
	var was: Dictionary = DeepForge.carat_band(DeepForge.at_hazard(here, tier), 1)
	if not band.is_empty():
		var said: String = "Up to %d ct" % int(band.cap) + (" · up from %d" % int(was.cap) if not was.is_empty() and int(was.cap) != int(band.cap) else "")
		DeepUi.pill(head, "gem", said, DeepUi.ACCENT_HI, 13, "Stones here usually come up to %d carats, and never over %d." % [int(band.soft), int(band.cap)]).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.gap(page, 10)
	var batch: Array = mine.get("batch", [])
	var columns: int = 3 if batch.size() <= 9 else 4
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(grid)
	var width: float = floorf((PAGE_WIDTH - 8.0 * (columns - 1)) / columns)
	for skill_key in batch:
		var def: Dictionary = DeepContent.skill(str(skill_key))
		var color: Color = DeepUi.color(str(def.get("color", "")))
		var rarity: String = str(def.get("rarity", "COMMON"))
		var card := PanelContainer.new()
		var style := DeepUi.flat(Color(color, 0.07), Color(color, 0.42), 10, 0)
		style.content_margin_left = 10
		style.content_margin_right = 8
		card.add_theme_stylebox_override("panel", style)
		card.custom_minimum_size = Vector2(width, 54)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.tooltip_text = "%s · %s %s skill" % [str(def.get("name", skill_key)), rarity.capitalize(), str(DeepContent.color(str(def.get("color", ""))).get("name", "")).to_lower()]
		grid.add_child(card)
		var line := DeepUi.hbox(card, 10)
		DeepUi.icon(line, GemIcons.emblem(str(skill_key)), 30, color).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var words := DeepUi.vbox(line, 0)
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		DeepUi.fit_label(words, str(def.get("name", skill_key)), 15, DeepUi.PAPER, width - 66.0, HORIZONTAL_ALIGNMENT_LEFT)
		DeepUi.label(words, rarity.capitalize(), 12, StoneCard._rarity_color(rarity))

static func _creatures(page: VBoxContainer, key: String, mine: Dictionary, here: Dictionary, met: Array) -> void:
	## The creatures filed under the mine in the bestiary, in its order: the ordinary ones,
	## then its Wardens and its boss. One not met yet is its shadow and no name.
	var head := DeepUi.section(page, "skull", "Down there", DeepUi.ACCENT, 13)
	var now: Dictionary = DeepDescent.creature_scale(mine, 1)
	var was: Dictionary = DeepDescent.creature_scale(here, 1)
	var hp: float = float(now.hp) / maxf(0.01, float(was.hp))
	var damage: float = float(now.damage) / maxf(0.01, float(was.damage))
	DeepUi.pill(head, "heart", "×%.1f health · ×%.1f damage" % [hp, damage], DeepUi.BAD, 13,
		"Its creatures are bred ×%.1f as tough and hit ×%.1f as hard as %s's." % [hp, damage, str(here.get("name", "here"))]).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.gap(page, 10)
	var keys: Array = DeepBestiary.in_mine(key).filter(func(k: Variant) -> bool: return DeepBestiary.role(str(k)) != "escort")
	var row := DeepUi.hbox(page, 8)
	var count: int = maxi(1, keys.size())
	var width: float = floorf((PAGE_WIDTH - 8.0 * (count - 1)) / count)
	var picture: float = minf(60.0, width - 12.0)
	for creature in keys:
		var creature_key: String = str(creature)
		var role: String = DeepBestiary.role(creature_key)
		var leader: bool = role in ["warden", "boss", "unmade"]
		var known: bool = met.has(creature_key)
		var def: Dictionary = DeepContent.creature(creature_key)
		var tile := PanelContainer.new()
		var style := DeepUi.flat(Color(DeepUi.BAD, 0.08 if role != "warden" else 0.06) if leader else Color(DeepUi.SLATE_HI, 0.45),
			Color(DeepUi.BAD, 0.6 if role != "warden" else 0.35) if leader else Color(0, 0, 0, 0), 10, 0)
		style.content_margin_top = 3
		style.content_margin_bottom = 6
		tile.add_theme_stylebox_override("panel", style)
		tile.custom_minimum_size.x = width
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		var called: String = {"warden": "A Warden", "boss": "The final boss", "unmade": "The Rift's own"}.get(role, "")
		tile.tooltip_text = (str(def.get("name", creature_key)) if known else "Not met yet") + ("\n" + called if not called.is_empty() else "")
		row.add_child(tile)
		var stack := DeepUi.vbox(tile, 1)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		var shot := TextureRect.new()
		var path: String = PORTRAITS + creature_key.to_lower() + ".png"
		shot.texture = load(path) if ResourceLoader.exists(path) else null
		shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		shot.custom_minimum_size = Vector2(picture, picture)
		shot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not known:
			shot.self_modulate = UNSEEN
		stack.add_child(shot)
		var tint: Color = DeepUi.BAD.lightened(0.25) if leader else (DeepUi.PAPER if known else DeepUi.MUTED)
		if known:
			DeepUi.fit_label(stack, str(def.get("name", creature_key)).trim_prefix("The "), 12, tint, width - 6.0)
		else:
			DeepUi.label(stack, "???", 13, tint, HORIZONTAL_ALIGNMENT_CENTER)
