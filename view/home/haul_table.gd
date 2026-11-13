extends VBoxContainer
## Coming home: the whole haul on one table (review page A3kZBgNsSHBe45J16ukSkd, every card
## approved November 13, 2026; docs/GOLD.md "Coming home").
##
## Every stone the run brought up lies on the table at once, in its rock: the stones read down
## the mine first, the raw ones by size, the Geodes last. One press of Crack all pays every fee
## (the purse covering what it can, the biggest stones first) and the rocks split one after
## another, the worst first so the best land last, light of the grade's color leaking out a beat
## before each gem shows, its grade stamped on, the notes climbing as the cascade runs. The
## Geodes crack after the stones, one at a time and struck by hand (the finale). Then the few
## stones worth a moment get the spotlight, the best last; the table slides into groups and every
## stone wears a suggested fate (DeepProfile.suggest_fates): into the vault, in place of yours,
## sold, turned in. A click on a card's fate (or 1 to 4 on the pane) changes it; a fate that
## would give up the finer stone turns red, and the bar says so. One press settles the lot: gold
## arcs into the purse, kept stones fly to the vault, a seal goes on what a commission takes.
## The report closes it: the best find on its plinth, what went into the vault, the gold, the
## vault filling, any record set, and the way into the workshop.
##
## The same table, without the hold on the workshop, is the vault's Unappraised view.

const GemView = preload("res://view/gems/gem_view.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const Geode = preload("res://view/gems/geode.gd")
const Spotlight = preload("res://view/gems/spotlight.gd")
const Appraisal = preload("res://view/gems/appraisal.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const Tips = preload("res://view/ui/tips.gd")
const Swipe = preload("res://view/ui/swipe.gd")

signal _finale_over

## Stones a page: the desk shows up to fifty at once, the phone eighteen.
const PAGE_DESK: int = 50
const PAGE_PHONE: int = 18
## The pane beside the grid, in pixels on the desk and points on the phone.
const PANE_DESK: float = 420.0
const PANE_PHONE: float = 222.0
## Spotlights a haul gives at most (C4): the best always among them.
const SPOTLIGHTS: int = 4
## The fates in the order the pane lists them; their mark, words and tone.
const FATE_ORDER: Array = ["vault", "replace", "sell", "turnin", "rough"]

var home: Control
## Coming home (the workshop waits on the table) or the vault's Unappraised view.
var holding: bool = true
## "laid", "cracking", "fates", "settling" or "report".
var phase: String = "laid"
var stones: Array = []
var order: Array = []
## What each card shows: a sealed copy until the card has been cracked on screen.
var shown: Dictionary = {}
## Each Geode's recipe, kept from before it was read, for its finale.
var recipes: Dictionary = {}
var fates: Dictionary = {}
var rough: Array = []
var focus: String = ""
var page: int = 0
var report: Dictionary = {}
var _cards: Dictionary = {}
var _grid: Grid = null
var _pane: VBoxContainer = null
var _bar: HBoxContainer = null
var _head: HBoxContainer = null
var _menu: Control = null
var _busy: bool = false
var _fast: bool = false
var _instant: bool = false
var _revealed: Dictionary = {}
## The keeps a player's choice pushed off, by the stone chosen: [[id, fate], ...].
var _pushed: Dictionary = {}

static func fate_look(fate: String) -> Array:
	## [glyph, words, short words, tone] for a fate.
	match fate:
		"vault": return ["chest", "Into the vault", "Vault", DeepUi.GOOD]
		"replace": return ["chest", "Replace yours", "Keep", DeepUi.GOOD]
		"sell": return ["scales", "Sell", "Sell", DeepUi.TRADE]
		"turnin": return ["flag", "Turn in", "Turn in", DeepUi.INFO]
		"rough": return ["scales", "Sell rough", "Rough", DeepUi.TRADE]
	return ["check", fate.capitalize(), fate.capitalize(), DeepUi.MUTED]

func _init(owner: Control = null, coming_home: bool = true) -> void:
	home = owner
	holding = coming_home
	name = "HaulTable"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", int(DeepUi.pt(6)) if DeepUi.phone else 12)
	_instant = DeepUi.headless()

func profile() -> Dictionary:
	return home.profile

# --- the table's state ---------------------------------------------------------------------------

func sync() -> void:
	## Called on every draw of the page: the table is kept between draws (home.kept), and only
	## reloads when the tray has changed under it while nothing is playing.
	if _busy:
		return
	var tray: Array = profile().get("tray", [])
	if phase == "report":
		return
	if tray.is_empty():
		if holding and profile().has("haul_report"):
			report = profile().haul_report
			phase = "report"
			_build()
		elif get_child_count() == 0:
			_build()
		return
	var ids: Array = tray.map(func(s: Dictionary) -> String: return str(s.get("id", "")))
	ids.sort()
	var have: Array = stones.map(func(s: Dictionary) -> String: return str(s.get("id", "")))
	have.sort()
	if ids != have or get_child_count() == 0:
		reload()

func reload() -> void:
	## The table drawn from the tray as it is now: unread stones put it before the crack, a tray
	## of known stones straight at its fates.
	stones = profile().get("tray", []).duplicate()
	rough = rough.filter(func(id: String) -> bool: return stones.any(func(s: Dictionary) -> bool: return str(s.id) == id and not bool(s.get("appraised", false))))
	if not profile().has("haul"):
		profile().haul = {"fees": 0, "purse": int(profile().get("gold", 0)), "vault": profile().get("vault", {}).size()}
	shown = {}
	for stone in stones:
		shown[str(stone.id)] = stone.duplicate(true)
		_warm(stone)
	var waiting: bool = stones.any(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)) and not rough.has(str(s.id)))
	phase = "laid" if waiting else "fates"
	if phase == "fates":
		_suggest()
		order = _grouped()
	else:
		order = _laid()
	page = 0
	if focus.is_empty() or not order.has(focus):
		focus = order[0] if not order.is_empty() else ""
	_build()

func _warm(stone: Dictionary) -> void:
	## The read stone's picture taken now, so a card cracked a moment later shows it at once.
	if Thumbs.headless() or bool(stone.get("appraised", false)) or DeepStone.is_geode(stone):
		return
	var known: Dictionary = stone.duplicate(true)
	known.appraised = true
	known.inclusions_revealed = true
	Thumbs.request(Thumbs.gem_key(known), "gem", {"stone": known}, func(_texture: Texture2D) -> void: pass)

func _stone(id: String) -> Dictionary:
	for stone in stones:
		if str(stone.get("id", "")) == id:
			return stone
	return {}

func _known(id: String) -> bool:
	return bool(_stone(id).get("appraised", false))

func _laid() -> Array:
	## Before the crack: stones read down the mine first (the finest first), the raw ones by
	## size, the Geodes last.
	var read: Array = stones.filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)))
	var raw: Array = stones.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)) and not DeepStone.is_geode(s))
	var geodes: Array = stones.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)) and DeepStone.is_geode(s))
	read.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return DeepProfile.better_stone(a, b))
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("carat", 1)) > int(b.get("carat", 1)))
	return (read + raw + geodes).map(func(s: Dictionary) -> String: return str(s.id))

func _best_id() -> String:
	var best: Dictionary = {}
	for stone in stones:
		if bool(stone.get("appraised", false)) and DeepProfile.better_stone(stone, best):
			best = stone
	return str(best.get("id", ""))

func _grouped() -> Array:
	## After the crack: the best of the haul first, then what goes into the vault, the upgrades,
	## what a commission takes, the sales, and anything sold rough; the finest first in each.
	var best: String = _best_id()
	var rank := func(s: Dictionary) -> int:
		if str(s.id) == best:
			return 0
		return 1 + FATE_ORDER.find(str(fates.get(str(s.id), "sell")))
	var list: Array = stones.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = rank.call(a)
		var rb: int = rank.call(b)
		if ra != rb:
			return ra < rb
		return DeepProfile.better_stone(a, b) if bool(a.get("appraised", false)) and bool(b.get("appraised", false)) else DeepStone.rough_value(a) > DeepStone.rough_value(b))
	return list.map(func(s: Dictionary) -> String: return str(s.id))

func _suggest() -> void:
	var suggested: Dictionary = DeepProfile.suggest_fates(profile(), stones)
	for id in rough:
		suggested[id] = "rough"
	fates = DeepProfile.normalize_fates(profile(), stones, suggested)

func set_fate(id: String, fate: String) -> void:
	## The player's own fate for a stone; the rest are held to what can happen around it.
	var stone: Dictionary = _stone(id)
	if phase != "fates" or stone.is_empty() or not DeepProfile.fates_for(profile(), stone, stones).has(fate):
		return
	var before: Dictionary = fates.duplicate()
	fates[id] = fate
	## A stone that pushed another of its skill off the keep, let go again, gives it back.
	if not fate in ["vault", "replace"]:
		for entry in _pushed.get(id, []):
			if str(fates.get(str(entry[0]), "")) == "sell":
				fates[str(entry[0])] = str(entry[1])
		_pushed.erase(id)
	fates = DeepProfile.normalize_fates(profile(), stones, fates, id)
	var pushed: Array = []
	for other in before:
		if str(other) != id and str(before[other]) in ["vault", "replace"] and not str(fates.get(other, "")) in ["vault", "replace"]:
			pushed.append([str(other), str(before[other])])
	if not pushed.is_empty():
		_pushed[id] = pushed
	DeepAudio.play("ui_toggle", {"volume": 0.7})
	_refresh_fates()
	_fill_pane()
	_fill_bar()

func toggle_rough(id: String) -> void:
	## Before the crack: a raw stone set aside to be sold as it is, or taken back to be read.
	if phase != "laid" or _known(id):
		return
	if rough.has(id):
		rough.erase(id)
	else:
		rough.append(id)
	DeepAudio.play("ui_toggle", {"volume": 0.7})
	var card: Card = _cards.get(id, null)
	if card != null:
		card.set_rough(rough.has(id), DeepStone.rough_value(_stone(id)))
	_fill_pane()
	_fill_bar()

# --- drawing ----------------------------------------------------------------------------------------

func _build() -> void:
	_close_menu()
	DeepUi.clear(self)
	_cards = {}
	_grid = null
	if phase == "report":
		_build_report()
		return
	if stones.is_empty():
		return
	var columns := DeepUi.hbox(self, int(DeepUi.pt(6)) if DeepUi.phone else 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := DeepUi.card(columns, Color(DeepUi.ACCENT, 0.3), int(DeepUi.pt(5)) if DeepUi.phone else 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_box := DeepUi.vbox(left, int(DeepUi.pt(3)) if DeepUi.phone else 8)
	_head = DeepUi.hbox(left_box, int(DeepUi.pt(5)) if DeepUi.phone else 10)
	_grid = Grid.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_child(_grid)
	if DeepUi.phone:
		Swipe.attach(_grid, func(way: int) -> void: turn_page(page + way), self)
	var right := DeepUi.card(columns, Color(DeepUi.ACCENT, 0.3), int(DeepUi.pt(6)) if DeepUi.phone else 16)
	right.custom_minimum_size.x = DeepUi.pt(PANE_PHONE) if DeepUi.phone else PANE_DESK
	_pane = DeepUi.vbox(right, int(DeepUi.pt(3)) if DeepUi.phone else 10)
	_pane.name = "HaulPane"
	var foot := DeepUi.card(self, Color(DeepUi.LINE, 0.9), int(DeepUi.pt(4)) if DeepUi.phone else 10, Color(0.045, 0.055, 0.09, 0.95))
	foot.name = "SettleBar"
	_bar = DeepUi.hbox(foot, int(DeepUi.pt(5)) if DeepUi.phone else 10)
	_bar.custom_minimum_size.y = DeepUi.pt(44) if DeepUi.phone else 48.0
	_fill_grid()
	_fill_pane()
	_fill_bar()

func _per_page() -> int:
	return PAGE_PHONE if DeepUi.phone else PAGE_DESK

func pages() -> int:
	return DeepUi.pages(order.size(), _per_page())

func turn_page(to: int) -> void:
	var at: int = clampi(to, 0, pages() - 1)
	if at == page:
		return
	page = at
	DeepAudio.play("ui_tap", {"volume": 0.6})
	_fill_grid()

func _fill_head() -> void:
	DeepUi.clear(_head)
	var size: int = 12 if DeepUi.phone else 15
	DeepUi.section(_head, "bag", ("The haul · %d" if DeepUi.phone else "The haul · %d stones") % stones.size(), DeepUi.ACCENT, size).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not DeepUi.phone:
		var chips := DeepUi.hbox(_head, 6)
		for entry in _head_counts():
			DeepUi.pill(chips, str(entry[0]), str(entry[1]), entry[2], 12)
	DeepUi.spacer(_head)
	if pages() > 1:
		DeepUi.pager(_head, page, pages(), turn_page, 12 if DeepUi.phone else 13)

func _head_counts() -> Array:
	## What the grid's head counts: before the crack what there is to read, after it what is
	## coming of it.
	var out: Array = []
	if phase in ["laid", "cracking"]:
		var raw: int = stones.filter(func(s: Dictionary) -> bool: return not bool(s.get("appraised", false)) and not DeepStone.is_geode(s)).size()
		var geodes: int = stones.filter(func(s: Dictionary) -> bool: return DeepStone.is_geode(s)).size()
		var read: int = stones.size() - raw - geodes
		if raw > 0:
			out.append(["loupe", "%d raw" % raw, DeepUi.MUTED])
		if geodes > 0:
			out.append(["geode", DeepUi.plural(geodes, "Geode"), DeepUi.ACCENT])
		if read > 0:
			out.append(["eye", "%d read in the mine" % read, DeepUi.INFO])
		return out
	var counts: Dictionary = {}
	for id in fates:
		counts[str(fates[id])] = int(counts.get(str(fates[id]), 0)) + 1
	if int(counts.get("vault", 0)) > 0:
		out.append(["star", "%d new" % int(counts.vault), StoneCard.PIP_NEW])
	if int(counts.get("replace", 0)) > 0:
		out.append(["rise", DeepUi.plural(int(counts.replace), "upgrade"), DeepUi.GOOD])
	return out

func _fill_grid() -> void:
	if _grid == null:
		return
	_fill_head()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cards = {}
	var on_page: Array = DeepUi.page_of(order, page, _per_page())
	_grid.shape(on_page.size())
	var list: Array = []
	for id in on_page:
		var card := Card.new(self, str(id), _grid.compact())
		_grid.add_child(card)
		_cards[str(id)] = card
		list.append(card)
		_dress(card)
	_grid.cards = list
	_grid.place(false)

func _dress(card: Card) -> void:
	## A card as the table stands: its stone (sealed until it has been cracked on screen), its
	## grade once read, its verdict and fate once the fates are out.
	var id: String = card.id
	var stone: Dictionary = _stone(id)
	var open: bool = bool(stone.get("appraised", false)) and (phase == "fates" or _revealed.has(id) or bool(shown.get(id, {}).get("appraised", false)))
	card.show_stone(stone if open else shown.get(id, stone), open)
	card.set_focus(id == focus)
	if open:
		card.set_grade(true)
	if phase == "fates":
		_dress_fate(card)
	elif rough.has(id):
		card.set_rough(true, DeepStone.rough_value(stone))
	elif bool(shown.get(id, {}).get("appraised", false)):
		card.set_ribbon("eye", "Read in the mine", DeepUi.MUTED)

func _verdict(stone: Dictionary) -> Array:
	## [glyph, words, tone] a card's ribbon says of its stone.
	var id: String = str(stone.get("id", ""))
	if not bool(stone.get("appraised", false)):
		return ["scales", "Not read", DeepUi.MUTED]
	if id == _best_id() and stones.size() > 1:
		return ["crown", "Best of haul", DeepUi.ACCENT_HI]
	var kept: Dictionary = DeepProfile.owned(profile(), str(stone.get("skill", "")))
	var fate: String = str(fates.get(id, ""))
	if kept.is_empty():
		return ["star", "New skill", StoneCard.PIP_NEW] if fate == "vault" else ["copy", "Another in this haul", DeepUi.MUTED]
	var found: int = int(DeepStone.grade(stone).score)
	var theirs: int = int(DeepStone.grade(kept).score)
	if DeepProfile.better_stone(stone, kept):
		return ["rise", "Upgrade +%d" % (found - theirs) if found > theirs else "Upgrade", DeepUi.GOOD]
	if not DeepEconomy.commission_for(profile(), stone).is_empty():
		return ["flag", "Wanted", DeepUi.INFO]
	if absi(found - theirs) <= 2:
		return ["scales", "Close call", Color("f0b35a")]
	return ["chest", "Yours: %d" % theirs, DeepUi.DIM]

func _dress_fate(card: Card) -> void:
	var stone: Dictionary = _stone(card.id)
	var said: Array = _verdict(stone)
	card.set_ribbon(str(said[0]), str(said[1]), said[2])
	var fate: String = str(fates.get(card.id, ""))
	if fate.is_empty():
		card.clear_fate()
		return
	var look: Array = fate_look(fate)
	var price: int = _price(stone, fate)
	var risky: bool = bool(_costly().get(card.id, false))
	card.set_fate(str(look[0]), str(look[1]), str(look[2]), price, look[3], risky)

func _price(stone: Dictionary, fate: String) -> int:
	## What a fate pays: a sale its worth, a rough sale its size's price, a commission its fee.
	match fate:
		"sell":
			return DeepStone.value(stone)
		"rough":
			return DeepStone.rough_value(stone)
		"turnin":
			var wanted: Dictionary = DeepEconomy.commission_for(profile(), stone)
			return DeepEconomy.payout(wanted, stone) if not wanted.is_empty() else 0
	return -1

func _costly() -> Dictionary:
	return DeepProfile.costly_fates(profile(), stones, fates)

func _refresh_fates() -> void:
	for id in _cards:
		_dress_fate(_cards[id])
	if _head != null:
		_fill_head()

func focus_on(id: String) -> void:
	if id == focus or _stone(id).is_empty():
		return
	focus = id
	for key in _cards:
		(_cards[key] as Card).set_focus(key == id)
	DeepAudio.play("ui_tap", {"volume": 0.5, "gap": 0.04})
	_fill_pane()

# --- the pane: the stone pointed at ------------------------------------------------------------------

func _fill_pane() -> void:
	if _pane == null or not is_instance_valid(_pane):
		return
	DeepUi.clear(_pane)
	var stone: Dictionary = _stone(focus)
	if stone.is_empty():
		return
	var open: bool = bool(stone.get("appraised", false)) and (phase == "fates" or _revealed.has(focus) or bool(shown.get(focus, {}).get("appraised", false)))
	if open:
		_pane_known(stone)
	else:
		_pane_raw(shown.get(focus, stone))

func _pane_raw(stone: Dictionary) -> void:
	## A stone still in its rock: what can be seen of it, what reading it costs, and the way to
	## sell it as it is instead.
	var phone: bool = DeepUi.phone
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(DeepUi.pt(120), DeepUi.pt(96)) if phone else Vector2(300, 240)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pane.add_child(stage)
	DeepUi.glow(stage, DeepUi.color(DeepStone.color(stone)), 0.18, 1.1)
	var thumb := Thumbs.GemThumb.new(stone, DeepUi.pt(92) if phone else 210.0)
	thumb.position = (stage.custom_minimum_size - thumb.custom_minimum_size) * 0.5
	stage.add_child(thumb)
	var geode: bool = DeepStone.is_geode(stone)
	var said: String = DeepStone.raw_name(stone)
	DeepUi.title(_pane, said if geode else "A " + said.to_lower(), 18 if phone else 28, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	var line: String
	if geode:
		var odds: Dictionary = DeepEconomy.geode_odds(stone.geode)
		var carats: Array = odds.get("carat", [1, 1])
		line = "%s. %d to %d ct inside; it cracks last, after the stones." % [Geode.geode_line(stone.geode), int(carats[0]), int(carats[1])]
	else:
		line = "%s. Its skill, Cut and Clarity show once it is cracked." % str(DeepStone.size_class(int(stone.get("carat", 1))).range).capitalize()
	DeepUi.wrap(_pane, line, 11 if phone else 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER, DeepUi.pt(200) if phone else 380.0)
	var facts := DeepUi.hbox(_pane, int(DeepUi.pt(4)) if phone else 8)
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	var fee: int = DeepProfile.appraisal_fee(stone)
	DeepUi.pill(facts, "coin", "Fee %d" % fee, DeepUi.ACCENT, 11 if phone else 13, "What reading it costs")
	DeepUi.pill(facts, "scales", "Rough +%d" % DeepStone.rough_value(stone), DeepUi.TRADE, 11 if phone else 13, "What a buyer gives for it unread")
	DeepUi.spacer(_pane, false)
	if phase == "laid":
		var marked: bool = rough.has(str(stone.id))
		var words: String = ("Read it after all" if marked else ("Sell it unopened" if geode else "Sell it rough instead"))
		var toggle := DeepUi.icon_button(_pane, "loupe" if marked else "scales", words, toggle_rough.bind(str(stone.id)), 12 if phone else 14, DeepUi.INFO if marked else DeepUi.TRADE)
		toggle.custom_minimum_size.y = DeepUi.pt(36) if phone else 44.0
		toggle.size_flags_horizontal = Control.SIZE_FILL
		if not marked:
			toggle.tooltip_text = "Leaves it out of Crack all: a buyer pays for its size and color, and you never learn what it was."
	elif phase == "fates":
		_pane_fates(stone)

func _pane_known(stone: Dictionary) -> void:
	## A read stone: what it is, how it weighs against the one kept, and its fates.
	var phone: bool = DeepUi.phone
	var top := DeepUi.hbox(_pane, int(DeepUi.pt(6)) if phone else 14)
	var art := Control.new()
	art.custom_minimum_size = Vector2.ONE * (DeepUi.pt(54) if phone else 112.0)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(art)
	var tier: String = str(DeepStone.grade(stone).tier)
	DeepUi.glow(art, DeepUi.tier_color(tier), 0.35, 1.5)
	var thumb := Thumbs.GemThumb.new(stone, art.custom_minimum_size.x)
	art.add_child(thumb)
	var words := DeepUi.vbox(top, int(DeepUi.pt(1)) if phone else 4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := DeepUi.title(words, DeepUi.skill_name(stone), 20 if phone else 32, GemMesh.tint(stone).lightened(0.35))
	title.clip_text = true
	var tags := DeepUi.hbox(words, int(DeepUi.pt(3)) if phone else 6)
	if not phone:
		StoneCard.rarity_tag(tags, str(DeepStone.skill_of(stone).get("rarity", "COMMON")), 12, false)
	var grade: Dictionary = DeepStone.grade(stone)
	DeepUi.pill(tags, "star", "%d %s" % [int(grade.score), str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier))], DeepUi.tier_color(str(grade.tier)), 11 if phone else 12, "Grade %d of 100" % int(grade.score))
	if not phone:
		DeepUi.label(words, "%d ct · %s · %s" % [int(stone.get("carat", 1)), DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.clarity_name(int(stone.get("clarity", 3)))], 13, DeepUi.MUTED)
		DeepUi.effect_text(_pane, DeepStone.text(stone), 13, DeepUi.MUTED, false, 384.0)
	var said: Array = _verdict_line(stone)
	var band := DeepUi.panel(_pane, Color(said[0], 0.1), Color(said[0], 0.45), 6, int(DeepUi.pt(4)) if phone else 10)
	var band_box := DeepUi.vbox(band, 1)
	var head := DeepUi.stat(band_box, str(said[1]), str(said[2]), said[0], 11 if phone else 15)
	head.add_theme_constant_override("separation", int(DeepUi.pt(3)) if phone else 6)
	if not phone and not str(said[3]).is_empty():
		DeepUi.wrap(band_box, str(said[3]), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 360.0)
	var rival: Dictionary = _rival(stone)
	if not rival.is_empty():
		_compare(_pane, stone, rival)
	if not phone:
		var inside: Array = stone.get("inclusions", [])
		if not inside.is_empty():
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 4)
			_pane.add_child(flow)
			for key in inside:
				var inclusion: Dictionary = DeepContent.inclusion(str(key))
				var cls: String = str(inclusion.get("class", "PINPOINT"))
				DeepUi.pill(flow, str(StoneCard.INCLUSION_GLYPHS.get(cls, "spark")), str(inclusion.get("name", key)), StoneCard.INCLUSION_TONES.get(cls, DeepUi.INFO), 12, str(inclusion.get("text", "")))
	DeepUi.spacer(_pane, false)
	if phase == "fates":
		_pane_fates(stone)
	elif not phone:
		DeepUi.label(_pane, "Its fate is set once the rest are cracked.", 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)

func _rival(stone: Dictionary) -> Dictionary:
	## What a stone is weighed against: the one of its skill kept, or else the finer of its skill
	## in this haul.
	var kept: Dictionary = DeepProfile.owned(profile(), str(stone.get("skill", "")))
	if not kept.is_empty():
		return kept
	var best: Dictionary = {}
	for other in stones:
		if str(other.get("id", "")) != str(stone.get("id", "")) and str(other.get("skill", "")) == str(stone.get("skill", "")) and bool(other.get("appraised", false)) and DeepProfile.better_stone(other, best):
			best = other
	return best

func _verdict_line(stone: Dictionary) -> Array:
	## [tone, glyph, the line, the line under it] the pane says of a read stone.
	var name: String = DeepUi.skill_name(stone)
	var kept: Dictionary = DeepProfile.owned(profile(), str(stone.get("skill", "")))
	var wanted: Dictionary = DeepEconomy.commission_for(profile(), stone)
	if kept.is_empty():
		var rival: Dictionary = _rival(stone)
		if not rival.is_empty() and DeepProfile.better_stone(rival, stone):
			return [DeepUi.MUTED, "copy", "A finer %s is in this haul" % name, "Only one of each skill is kept."]
		return [StoneCard.PIP_NEW, "star", "A new skill", ("The first %s for the vault. A first stone is never sold." % name) if wanted.is_empty() else ("A commission wants it too: %d gold." % DeepEconomy.payout(wanted, stone))]
	var found: int = int(DeepStone.grade(stone).score)
	var theirs: int = int(DeepStone.grade(kept).score)
	if DeepProfile.better_stone(stone, kept):
		return [DeepUi.GOOD, "rise", "Upgrade: grade %d against yours %d" % [found, theirs], "Keeping it lets yours go for no gold."]
	if not wanted.is_empty():
		return [DeepUi.INFO, "flag", "A commission wants it: %d gold" % DeepEconomy.payout(wanted, stone), "It sells for %d. Yours (grade %d) is the finer stone." % [DeepStone.value(stone), theirs]]
	if absi(found - theirs) <= 2:
		return [Color("f0b35a"), "scales", "Close call: grade %d against yours %d" % [found, theirs], "Yours is worth %d, this one %d." % [DeepStone.value(kept), DeepStone.value(stone)]]
	return [DeepUi.MUTED, "chest", "Yours is finer: %d against %d" % [theirs, found], "Sell it for %d." % DeepStone.value(stone)]

func _compare(parent: Control, stone: Dictionary, rival: Dictionary) -> void:
	## The two stones side by side, the better value of each line in green.
	var phone: bool = DeepUi.phone
	var size: int = 11 if phone else 13
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(DeepUi.pt(8)) if phone else 16)
	grid.add_theme_constant_override("v_separation", 0 if phone else 2)
	parent.add_child(grid)
	var kept: bool = not DeepProfile.owned(profile(), str(stone.get("skill", ""))).is_empty()
	var found: Dictionary = DeepStone.grade(stone)
	var theirs: Dictionary = DeepStone.grade(rival)
	var rows: Array = [["", "Found", "Yours" if kept else "The other", 0]]
	if not phone:
		rows.append(["Carat", "%d ct" % int(stone.get("carat", 1)), "%d ct" % int(rival.get("carat", 1)), int(stone.get("carat", 1)) - int(rival.get("carat", 1))])
		rows.append(["Cut", DeepContent.cut_name(int(stone.get("cut", 0))), DeepContent.cut_name(int(rival.get("cut", 0))), int(stone.get("cut", 0)) - int(rival.get("cut", 0))])
		rows.append(["Clarity", DeepContent.clarity_name(int(stone.get("clarity", 3))), DeepContent.clarity_name(int(rival.get("clarity", 3))), 0])
	rows.append(["Grade", "%d" % int(found.score), "%d" % int(theirs.score), int(found.score) - int(theirs.score)])
	rows.append(["Worth", str(DeepStone.value(stone)), str(DeepStone.value(rival)), DeepStone.value(stone) - DeepStone.value(rival)])
	for row in rows:
		var head: bool = str(row[0]).is_empty()
		DeepUi.label(grid, str(row[0]), size, DeepUi.MUTED)
		var a := DeepUi.label(grid, str(row[1]), size, DeepUi.DIM if head else (DeepUi.GOOD if int(row[3]) > 0 else DeepUi.PAPER))
		var b := DeepUi.label(grid, str(row[2]), size, DeepUi.DIM if head else (DeepUi.GOOD if int(row[3]) < 0 else DeepUi.MUTED))
		if not head:
			a.add_theme_font_override("font", DeepUi.bold_font())
			b.add_theme_font_override("font", DeepUi.bold_font())

func _pane_fates(stone: Dictionary) -> void:
	## The stone's fates as buttons, two to a row, the chosen one filled; 1 to 4 on the desk.
	var phone: bool = DeepUi.phone
	if not phone:
		DeepUi.heading(_pane, "What happens to it", 13, DeepUi.ACCENT)
	var offered: Array = DeepProfile.fates_for(profile(), stone, stones)
	if offered.is_empty():
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(DeepUi.pt(4)) if phone else 8)
	grid.add_theme_constant_override("v_separation", int(DeepUi.pt(4)) if phone else 8)
	_pane.add_child(grid)
	var costly: Dictionary = _costly()
	for index in range(offered.size()):
		var fate: String = str(offered[index])
		var look: Array = fate_look(fate)
		var on: bool = str(fates.get(str(stone.id), "")) == fate
		var risky: bool = on and bool(costly.get(str(stone.id), false))
		var tone: Color = DeepUi.BAD if risky else look[3]
		var words: String = str(look[1]) if not phone or str(look[1]).length() <= 12 else str(look[2])
		var button: Button
		if on:
			button = DeepUi.primary(grid, str(look[0]), words, set_fate.bind(str(stone.id), fate), 12 if phone else 14, DeepUi.coin_safe(tone))
		else:
			button = DeepUi.icon_button(grid, str(look[0]), words, set_fate.bind(str(stone.id), fate), 12 if phone else 14, tone)
		button.name = "Fate_" + fate
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, DeepUi.pt(44) if phone else 48.0)
		var price: int = _price(stone, fate)
		if price > 0:
			DeepUi.priced(button, "+%d" % price)
		if not phone:
			button.tooltip_text = "%s · press %d" % [str(look[1]), index + 1]
	if bool(costly.get(str(stone.id), false)):
		DeepUi.stat(_pane, "cross", "This gives up the finer stone", DeepUi.BAD, 11 if phone else 13)

# --- the settle bar ---------------------------------------------------------------------------------

func _fill_bar() -> void:
	if _bar == null or not is_instance_valid(_bar):
		return
	DeepUi.clear(_bar)
	var phone: bool = DeepUi.phone
	var size: int = 11 if phone else 14
	match phase:
		"laid":
			var plan: Dictionary = DeepProfile.crack_plan(profile(), stones, rough)
			var gold: int = int(profile().get("gold", 0))
			var reading: int = plan.crack.size() + plan.short.size()
			if reading > 0:
				DeepUi.stat(_bar, "loupe", ("%d to read" if phone else "%s to read and crack, the fees paid together") % ([reading] if phone else [DeepUi.plural(reading, "stone")]), DeepUi.MUTED, size)
			if not rough.is_empty():
				DeepUi.pill(_bar, "scales", "%d to sell rough" % rough.size(), DeepUi.TRADE, size)
			if not plan.short.is_empty():
				DeepUi.stat(_bar, "coin", ("Short %d: the rest sell rough" if phone else "The purse covers %d of %d: the rest sell rough") % ([plan.short.size()] if phone else [plan.crack.size(), plan.crack.size() + plan.short.size()]), DeepUi.BAD, size)
			DeepUi.spacer(_bar)
			DeepUi.stat(_bar, "coin", ("%s" if phone else "Purse %s") % DeepUi.number(gold), DeepUi.MUTED, size, "Your purse")
			var words: String = "Crack all" if plan.short.is_empty() else "Crack %d" % plan.crack.size()
			if plan.crack.is_empty():
				words = "Sell them rough" if not plan.short.is_empty() or not rough.is_empty() else "Go on"
			var go := DeepUi.primary(_bar, "hammer" if not plan.crack.is_empty() else "scales", words, crack_all, 14 if phone else 18)
			go.name = "CrackAll"
			if int(plan.fee) > 0:
				DeepUi.priced(go, str(int(plan.fee)))
			go.custom_minimum_size = Vector2(DeepUi.pt(120), DeepUi.pt(44)) if phone else Vector2(250, 48)
			if not phone:
				go.tooltip_text = "Reads every stone at once, the fees paid together (Space)"
			if not _instant:
				DeepUi.breathe(go, 0.85, 1.6)
		"cracking":
			var left: int = stones.filter(func(st: Dictionary) -> bool: return not _revealed.has(str(st.id)) and not rough.has(str(st.id))).size()
			DeepUi.stat(_bar, "hammer", "Cracking · %d to go" % left if left > 0 else "Cracking…", DeepUi.PAPER, size)
			DeepUi.spacer(_bar)
			DeepUi.label(_bar, "Hold anywhere to run it fast" if phone else "Hold the mouse or Space to run it three times as fast", size, DeepUi.MUTED)
		"fates":
			var counts: Dictionary = {}
			var gold_in: int = 0
			for id in fates:
				var fate: String = str(fates[id])
				counts[fate] = int(counts.get(fate, 0)) + 1
				gold_in += maxi(0, _price(_stone(str(id)), fate))
			for entry in [["vault", "star", "%d new", StoneCard.PIP_NEW], ["replace", "rise", "%d upgraded", DeepUi.GOOD], ["turnin", "flag", "%d turned in", DeepUi.INFO], ["sell", "scales", "%d sold", DeepUi.TRADE], ["rough", "scales", "%d sold rough", DeepUi.TRADE]]:
				var n: int = int(counts.get(str(entry[0]), 0))
				if n > 0:
					DeepUi.pill(_bar, str(entry[1]), (str(n) if phone else str(entry[2]) % n), entry[3], size)
			var costly: Dictionary = _costly()
			if not costly.is_empty():
				var warn := DeepUi.icon_button(_bar, "cross", (str(costly.size()) if phone else "%s up a finer stone · Show" % ("1 choice gives" if costly.size() == 1 else "%d choices give" % costly.size())), _show_costly, size, DeepUi.BAD)
				warn.name = "CostlyWarning"
				warn.custom_minimum_size.y = DeepUi.pt(30) if phone else 34.0
			DeepUi.spacer(_bar)
			var settle := DeepUi.primary(_bar, "check", "Settle" if phone else "Settle the haul", settle, 14 if phone else 18)
			settle.name = "Settle"
			if gold_in > 0:
				DeepUi.priced(settle, "+%d" % gold_in)
			settle.custom_minimum_size = Vector2(DeepUi.pt(110), DeepUi.pt(44)) if phone else Vector2(250, 48)
			if not phone:
				settle.tooltip_text = "Every stone goes as its card says (Enter)"
		"settling":
			DeepUi.stat(_bar, "check", "Settling…", DeepUi.PAPER, size)
	for child in _bar.get_children():
		if child is Control:
			(child as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _show_costly() -> void:
	## The bar's warning: the first card whose fate gives up a finer stone, put under the pane.
	var costly: Dictionary = _costly()
	for id in order:
		if costly.has(str(id)):
			var at: int = order.find(str(id))
			var to: int = at / _per_page()
			if to != page:
				page = to
				_fill_grid()
			focus_on(str(id))
			var card: Card = _cards.get(str(id), null)
			if card != null:
				DeepUi.pulse(card, 1.06, 0.3)
			return

# --- the crack ----------------------------------------------------------------------------------

func crack_all() -> void:
	## Pays every fee the purse covers (the biggest stones first) and reads those stones; what
	## the purse cannot cover, and anything set aside, is sold rough. Then the cascade.
	if _busy or phase != "laid":
		return
	var plan: Dictionary = DeepProfile.crack_plan(profile(), stones, rough)
	for id in plan.short:
		if not rough.has(str(id)):
			rough.append(str(id))
	var paid: int = 0
	var cracked: Array = []
	for id in plan.crack:
		var stone: Dictionary = _stone(str(id))
		if DeepStone.is_geode(stone):
			recipes[str(id)] = stone.geode.duplicate(true)
		var fee: int = DeepProfile.appraisal_fee(stone)
		if DeepProfile.appraise(profile(), stone):
			paid += fee
			cracked.append(str(id))
	profile().haul = profile().get("haul", {})
	profile().haul.fees = int(profile().haul.get("fees", 0)) + paid
	home.touch()
	if paid > 0 and not _instant:
		DeepAudio.play("buy", {"volume": 0.7})
	if home.has_method("_draw_bar"):
		home.call("_draw_bar")
	phase = "cracking"
	if _instant:
		_after_crack()
		return
	_busy = true
	_fill_bar()
	_cascade(cracked)

func _wait(seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.create_timer(seconds / (3.0 if _fast else 1.0)).timeout

func _process(_delta: float) -> void:
	_fast = _busy and (Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func _cascade(cracked: Array) -> void:
	## The rocks split one after another, a page at a time, the worst first; then the Geodes,
	## one by one; then the spotlights.
	var raw: Array = cracked.filter(func(id: String) -> bool: return not recipes.has(id))
	var geodes: Array = cracked.filter(func(id: String) -> bool: return recipes.has(id))
	var by_grade := func(a: String, b: String) -> bool: return not DeepProfile.better_stone(_stone(a), _stone(b))
	raw.sort_custom(by_grade)
	geodes.sort_custom(by_grade)
	var step: int = 0
	for at in range(pages()):
		var on_page: Array = DeepUi.page_of(order, at, _per_page())
		var here: Array = raw.filter(func(id: String) -> bool: return on_page.has(id))
		if here.is_empty():
			continue
		if at != page:
			page = at
			_fill_grid()
			await _wait(0.35)
		for id in here:
			if not is_inside_tree():
				await _wait(0.1)
			await _crack_card(str(id), step)
			step += 1
	await _wait(0.35)
	for id in geodes:
		await _finale(str(id))
	await _spotlights(cracked)
	_after_crack()

func _crack_card(id: String, step: int) -> void:
	## One rock: it shakes, light of its grade's color leaks through the cracks, it splits in a
	## spray, the gem shows, and its grade is stamped on with the next note up.
	var stone: Dictionary = _stone(id)
	var card: Card = _cards.get(id, null)
	var tier: String = str(DeepStone.grade(stone).tier)
	var rank: int = DeepStone.TIERS.find(tier)
	var tone: Color = DeepUi.tier_color(tier)
	if card == null or not card.is_inside_tree():
		_revealed[id] = true
		return
	card.crack(tone, [0.3, 0.5, 0.72, 0.92, 1.0][clampi(rank, 0, 4)])
	DeepAudio.play("chisel", {"volume": 0.55, "gap": 0.02})
	await _wait(0.14 + 0.06 * float(rank))
	_revealed[id] = true
	var known: Dictionary = stone.duplicate(true)
	shown[id] = known
	card.open_up(known, tone, rank)
	_fill_bar()
	DeepAudio.play(DeepSoundBank.tick_sound(DeepStone.color(known)), {"pitch": minf(2.3, 0.85 + 0.06 * float(step)), "volume": 0.8, "gap": 0.0})
	if focus == id or focus.is_empty() or phase == "cracking":
		focus = id
		for key in _cards:
			(_cards[key] as Card).set_focus(key == id)
		_fill_pane()
	await _wait(0.07)
	card.stamp()
	if rank >= 1:
		DeepAudio.play(DeepSoundBank.grade_sound(tier), {"volume": 0.35 + 0.12 * float(rank), "gap": 0.0})
	await _wait(0.13)

func _finale(id: String) -> void:
	## A Geode cracked big, by hand: three blows (or a held press), its light telling how good
	## it is; the stone it held lands on its card.
	var stone: Dictionary = _stone(id)
	var card: Card = _cards.get(id, null)
	if card == null:
		var at: int = order.find(id) / _per_page()
		if at != page:
			page = at
			_fill_grid()
			card = _cards.get(id, null)
	var layer: CanvasLayer = Geode.open(recipes.get(id, {}), stone, {"finale": true}, func() -> void: _finale_over.emit())
	if layer != null:
		await _finale_over
	_revealed[id] = true
	var known: Dictionary = stone.duplicate(true)
	shown[id] = known
	if card != null and is_instance_valid(card):
		var tier: String = str(DeepStone.grade(stone).tier)
		card.open_up(known, DeepUi.tier_color(tier), DeepStone.TIERS.find(tier))
		card.stamp()
	focus = id
	for key in _cards:
		(_cards[key] as Card).set_focus(key == id)
	_fill_pane()
	await _wait(0.3)

func _spotlights(cracked: Array) -> void:
	## The few worth a moment (C4): every new skill, the best of the haul, anything Exquisite or
	## better, opals; four at most, the best always among them and always last. A fall's haul
	## gives its best find alone.
	var low: bool = _fallen()
	var suggested: Dictionary = DeepProfile.suggest_fates(profile(), stones)
	var best: String = ""
	var found: Array = cracked.map(func(id: String) -> Dictionary: return _stone(id)).filter(func(s: Dictionary) -> bool: return not s.is_empty() and bool(s.get("appraised", false)))
	for stone in found:
		if best.is_empty() or DeepProfile.better_stone(stone, _stone(best)):
			best = str(stone.id)
	if best.is_empty():
		return
	var picked: Array = []
	if not low:
		for stone in found:
			var tier: int = DeepStone.TIERS.find(str(DeepStone.grade(stone).tier))
			if str(suggested.get(str(stone.id), "")) == "vault" or tier >= DeepStone.TIERS.find("EXQUISITE") or DeepStone.is_opal(stone):
				if str(stone.id) != best:
					picked.append(stone)
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return DeepProfile.better_stone(a, b))
	picked = picked.slice(0, SPOTLIGHTS - 1)
	picked.reverse()
	picked.append(_stone(best))
	var colors_seen: Dictionary = {}
	var fresh_seen: int = 0
	var record: int = int(profile().get("records", {}).get("best", {}).get("score", -1))
	for index in range(picked.size()):
		var stone: Dictionary = picked[index]
		var kept: Dictionary = DeepProfile.owned(profile(), str(stone.get("skill", "")))
		var fresh: bool = kept.is_empty() and str(suggested.get(str(stone.id), "")) == "vault"
		var color: String = DeepStone.color(stone)
		var have: Array = DeepProfile._owned_of_color(profile(), color)
		var opts: Dictionary = {"index": index, "count": picked.size(), "low": low, "owned": kept,
			"kind": "best" if str(stone.id) == best else ("new" if fresh else ("upgrade" if DeepProfile.better_stone(stone, kept) else "find")), "fresh": fresh}
		if fresh:
			opts.slot = {"color": [int(have[0]) + int(colors_seen.get(color, 0)), int(have[1])], "vault": [profile().get("vault", {}).size() + fresh_seen, DeepProfile.known_skills(profile()).size()]}
			colors_seen[color] = int(colors_seen.get(color, 0)) + 1
			fresh_seen += 1
		var score: int = int(DeepStone.grade(stone).score)
		if str(stone.id) == best and record >= 0 and score > record:
			opts.records = [["crown", "Your best grade yet (was %d)" % record]]
		var layer: CanvasLayer = Spotlight.show_stone(stone, opts)
		if layer == null:
			continue
		var how: String = await layer.done
		if how == "skip":
			break

func _fallen() -> bool:
	var history: Array = profile().get("history", [])
	return holding and not history.is_empty() and str(history.back().get("outcome", "")) == "fallen"

func _after_crack() -> void:
	## Every rock is open: the fates are suggested, the cards slide into their groups and put
	## their verdicts and fates on, the best first under the pane.
	_busy = false
	for stone in stones:
		_revealed[str(stone.id)] = true
	phase = "fates"
	_suggest()
	var before: Array = order.duplicate()
	order = _grouped()
	focus = order[0] if not order.is_empty() else ""
	page = 0
	if _instant or _grid == null:
		_build()
		return
	## The slide: cards keep their place for a frame, then move to their group's.
	var on_page: Array = DeepUi.page_of(order, 0, _per_page())
	var same_page: bool = on_page.all(func(id: String) -> bool: return _cards.has(id)) and on_page.size() == _cards.size() and before.size() == order.size()
	if not same_page:
		_fill_grid()
	else:
		var list: Array = []
		for id in on_page:
			list.append(_cards[id])
		_grid.cards = list
		_grid.place(true)
	_fill_head()
	_fill_pane()
	_fill_bar()
	var step: float = 0.0
	for id in on_page:
		var card: Card = _cards.get(id, null)
		if card == null:
			continue
		card.set_focus(id == focus)
		var at := card.create_tween()
		at.tween_interval(0.45 + step)
		at.tween_callback(func() -> void:
			if is_instance_valid(card):
				_dress_fate(card)
				card.flourish())
		step += 0.03
	DeepAudio.play("ui_open", {"volume": 0.6, "delay": 0.45})

# --- settling ------------------------------------------------------------------------------------

func settle() -> void:
	## Every stone goes as its card says. Gold arcs into the purse, kept stones fly to the vault,
	## a seal goes on what a commission takes; then the report.
	if _busy or phase != "fates":
		return
	_close_menu()
	var flights: Array = []
	if not _instant:
		for id in _cards:
			var card: Card = _cards[id]
			if card.is_inside_tree():
				flights.append([card, str(fates.get(id, "")), _stone(id).duplicate(true)])
	var vault_before: int = profile().get("vault", {}).size()
	var done: Dictionary = DeepProfile.settle_tray(profile(), fates)
	var haul: Dictionary = profile().get("haul", {})
	done.fees = int(haul.get("fees", 0))
	done.purse_from = int(haul.get("purse", profile().get("gold", 0)))
	done.purse_to = int(profile().get("gold", 0))
	done.vault_from = int(haul.get("vault", vault_before))
	done.vault_to = profile().get("vault", {}).size()
	done.crown = _crown_came_home(done)
	done.fallen = _fallen()
	done.stones = stones.size()
	report = done
	if holding:
		profile().haul_report = done
	home.touch()
	phase = "settling"
	if _instant:
		phase = "report"
		_build()
		return
	_busy = true
	_fill_bar()
	await _fly(flights)
	if home.has_method("_draw_bar"):
		home.call("_draw_bar")
	await _wait(0.55)
	_busy = false
	phase = "report"
	_build()

func _crown_came_home(done: Dictionary) -> bool:
	## Whether the run's Crown Jewel (its most useful gem, by the run end's own points) was one
	## of the stones kept.
	var history: Array = profile().get("history", [])
	if history.is_empty() or not holding:
		return false
	var gems: Dictionary = history.back().get("stats", {}).get("gems", {})
	var best: String = ""
	var most: int = -1
	var points := func(tally: Dictionary) -> int: return int(load("res://view/run/descent_screen.gd").points_of(tally, false))
	for id in gems:
		if gems[id] is Dictionary and int(gems[id].get("fires", 0)) > 0:
			var p: int = points.call(gems[id])
			if p > most:
				most = p
				best = str(id)
	return not best.is_empty() and done.get("kept", []).any(func(e: Dictionary) -> bool: return str(e.stone.get("id", "")) == best)

func _target(name: String) -> Vector2:
	## Where a flight lands, in the home screen's own space: the purse, or the vault's mark (the
	## Vault tab, away from coming home).
	var node: Node = home.find_child(name, true, false)
	if node == null and name == "VaultMark":
		node = home.find_child("Tab_vault", true, false)
	if node is Control and (node as Control).is_inside_tree():
		var c: Control = node
		return c.global_position + c.size * 0.5 - home.global_position
	return Vector2(home.size.x * 0.5, 0)

func _fly(flights: Array) -> void:
	var purse: Vector2 = _target("Purse")
	var vault: Vector2 = _target("VaultMark")
	var delay: float = 0.0
	var sold: int = 0
	var kept: int = 0
	for flight in flights:
		var card: Card = flight[0]
		if not is_instance_valid(card):
			continue
		var from: Vector2 = card.global_position + card.size * 0.5 - home.global_position
		var fate: String = str(flight[1])
		var stone: Dictionary = flight[2]
		match fate:
			"vault", "replace":
				_flyer_gem(stone, from, vault, delay)
				kept += 1
			"turnin":
				card.seal()
				for coin in range(3):
					_flyer_coin(from, purse, delay + 0.25 + 0.08 * coin)
				sold += 1
			_:
				for coin in range(2):
					_flyer_coin(from, purse, delay + 0.08 * coin)
				sold += 1
		var fade := card.create_tween()
		fade.tween_interval(delay + 0.15)
		fade.tween_property(card, "modulate:a", 0.35, 0.3)
		delay += 0.045
	if sold > 0:
		DeepAudio.play("sell", {"volume": 0.8})
		DeepAudio.play("ore", {"delay": 0.55, "volume": 0.7})
	if kept > 0:
		DeepAudio.play("keep", {"delay": 0.3, "volume": 0.85})
	await _wait(0.9 + delay)

func _flyer_coin(from: Vector2, to: Vector2, delay: float) -> void:
	var coin := TextureRect.new()
	coin.texture = load("res://view/gems/gem_icons.gd").texture("coin", 64)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var edge: float = DeepUi.pt(12) if DeepUi.phone else 22.0
	coin.size = Vector2(edge, edge)
	coin.modulate = Color(DeepUi.ACCENT_HI, 0.0)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.z_index = 45
	_arc(coin, from, to, delay, 0.75, edge)

func _flyer_gem(stone: Dictionary, from: Vector2, to: Vector2, delay: float) -> void:
	var edge: float = DeepUi.pt(30) if DeepUi.phone else 64.0
	var thumb := Thumbs.GemThumb.new(stone, edge)
	thumb.live_on_hover = false
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.size = Vector2(edge, edge)
	thumb.modulate.a = 0.0
	thumb.z_index = 45
	_arc(thumb, from, to, delay, 0.85, edge, true)

func _arc(node: Control, from: Vector2, to: Vector2, delay: float, seconds: float, edge: float, shrink: bool = false) -> void:
	## Up and over in a curve, landing with a little burst where it lands.
	home.add_child(node)
	node.position = from - Vector2(edge, edge) * 0.5
	var lift: float = DeepUi.pt(90) if DeepUi.phone else 220.0
	var mid: Vector2 = Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - lift)
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, 0.08)
	tween.tween_method(func(t: float) -> void:
		var p: Vector2 = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		node.position = p - node.size * 0.5
		if shrink:
			node.scale = Vector2.ONE * lerpf(1.0, 0.45, t), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		DeepUi.burst(home, to, DeepUi.ACCENT_HI if not shrink else StoneCard.PIP_NEW, 10, 140.0, 0.45, 4.0)
		node.queue_free())

# --- the report -----------------------------------------------------------------------------------

func _build_report() -> void:
	## The haul is in: the best find on its plinth, what went into the vault, the gold, the
	## vault meter, any record set; and the way on.
	var phone: bool = DeepUi.phone
	var kept: Array = report.get("kept", [])
	var best: Dictionary = report.get("best", {})
	var fallen: bool = bool(report.get("fallen", false))
	var history: Array = profile().get("history", [])
	var last: Dictionary = history.back() if not history.is_empty() else {}
	var head := DeepUi.vbox(self, 0)
	var title := DeepUi.title(head, "Salvaged" if fallen else "The haul is in", 24 if phone else 42, DeepUi.MUTED.lightened(0.3) if fallen else DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "ReportTitle"
	var where: String = DeepContent.mine_name(str(last.get("mine", DeepContent.starter_mine()))) if holding else "The vault"
	var line: String = "%s · %s · worth %s gold" % [where, DeepUi.plural(int(report.get("stones", 0)), "stone"), DeepUi.number(int(report.get("worth", 0)))]
	DeepUi.label(head, line, 11 if phone else 15, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var middle := DeepUi.hbox(self, int(DeepUi.pt(6)) if phone else 18)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if phone:
		_report_plinth(middle, best, 104.0)
		_report_vault(middle, kept, 196.0)
		_report_gold(middle, 0.0)
	else:
		_report_vault(middle, kept, 420.0)
		_report_plinth(middle, best, 270.0)
		_report_gold(middle, 420.0)
	_report_foot(kept, best)
	if not _instant:
		DeepUi.pop_in(title, 0.0, 0.9, 0.4)
		DeepAudio.play("victory" if not fallen else "reveal", {"volume": 0.55})

func _report_plinth(parent: Control, best: Dictionary, edge: float) -> void:
	var phone: bool = DeepUi.phone
	var column := DeepUi.vbox(parent, int(DeepUi.pt(2)) if phone else 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	if best.is_empty():
		return
	var tier: String = str(DeepStone.grade(best).tier)
	var tone: Color = DeepUi.tier_color(tier)
	var badge := DeepUi.pill(column, "crown", "Best of the haul", DeepUi.ACCENT_HI, 11 if phone else 15)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var stage := Control.new()
	stage.custom_minimum_size = Vector2.ONE * (DeepUi.pt(edge) if phone else edge)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	var rays := Inspector.Rays.new(tone)
	rays.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rays.size = Vector2.ONE * stage.custom_minimum_size.x * 3.0
	rays.position = -rays.size * 0.5 + stage.custom_minimum_size * 0.5
	rays.set("offset", Vector2.ZERO)
	rays.modulate.a = 0.5
	stage.add_child(rays)
	DeepUi.glow(stage, tone, 0.45, 1.5)
	var view: Control
	if Thumbs.headless():
		view = Thumbs.GemThumb.new(best, stage.custom_minimum_size.x)
	else:
		view = GemView.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.call("set_slot", stage.custom_minimum_size.x * 0.72)
		view.call("set_drift", true)
		view.call("set_spin", 0.6)
		view.call("configure", best)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(view)
	if not _instant:
		stage.pivot_offset = stage.custom_minimum_size * 0.5
		stage.scale = Vector2.ONE * 0.4
		stage.create_tween().tween_property(stage, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	DeepUi.title(column, DeepUi.skill_name(best), 22 if phone else 40, GemMesh.tint(best).lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
	var stamp := DeepUi.pill(column, "star", "%d · %s" % [int(DeepStone.grade(best).score), str(DeepStone.TIER_NAMES.get(tier, tier))], tone, 13 if phone else 22)
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ribbons: Array = report.get("records", []).duplicate()
	if bool(report.get("crown", false)):
		ribbons.append(["crowned_gem", "The Crown Jewel came home", "crown"])
	if not ribbons.is_empty():
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", int(DeepUi.pt(3)) if phone else 8)
		flow.add_theme_constant_override("v_separation", int(DeepUi.pt(2)) if phone else 6)
		flow.custom_minimum_size.x = DeepUi.pt(200) if phone else 560.0
		flow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(flow)
		var shown_ribbons: Array = ribbons.slice(0, 2) if phone else ribbons
		for index in range(shown_ribbons.size()):
			var entry: Array = shown_ribbons[index]
			var ribbon := DeepUi.pill(flow, str(entry[0]), str(entry[1]), _ribbon_tone(str(entry[2])), 11 if phone else 15)
			if not _instant:
				DeepUi.pop_in(ribbon, 0.7 + 0.15 * float(index), 0.6, 0.4)
				ribbon.create_tween().tween_callback(func() -> void: DeepAudio.play("star", {"volume": 0.7})).set_delay(0.7 + 0.15 * float(index))

func _ribbon_tone(kind: String) -> Color:
	match kind:
		"best", "haul", "crown":
			return DeepUi.ACCENT_HI
		"EXQUISITE", "PEERLESS":
			return DeepUi.tier_color(kind)
		"OPAL":
			return DeepUi.OPAL_TONE
		"milestone":
			return StoneCard.PIP_NEW
	if DeepStone.colorS.has(kind):
		return DeepUi.color(kind).lightened(0.2)
	return DeepUi.ACCENT

func _report_vault(parent: Control, kept: Array, width: float) -> void:
	var phone: bool = DeepUi.phone
	var card := DeepUi.card(parent, Color(DeepUi.ACCENT, 0.3), int(DeepUi.pt(5)) if phone else 16)
	card.custom_minimum_size.x = DeepUi.pt(width) if phone else width
	var box := DeepUi.vbox(card, int(DeepUi.pt(1)) if phone else 4)
	DeepUi.section(box, "chest", "Into the vault · %d" % kept.size(), DeepUi.ACCENT, 11 if phone else 15)
	if kept.is_empty():
		DeepUi.wrap(box, "Nothing new for the vault this time." + (" Everything went to the buyers." if not report.get("sold", []).is_empty() else ""), 11 if phone else 14, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, DeepUi.pt(180) if phone else 380.0)
		return
	var room: int = 5 if phone else 9
	var list: Array = kept.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("fresh", false)) != bool(b.get("fresh", false)):
			return bool(a.get("fresh", false))
		return DeepProfile.better_stone(a.stone, b.stone))
	for index in range(mini(list.size(), room if list.size() <= room else room - 1)):
		var entry: Dictionary = list[index]
		var row := DeepUi.hbox(box, int(DeepUi.pt(4)) if phone else 10)
		row.custom_minimum_size.y = DeepUi.pt(26) if phone else 52.0
		var thumb := Thumbs.GemThumb.new(entry.stone, DeepUi.pt(22) if phone else 42.0)
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(thumb)
		var name := DeepUi.label(row, DeepUi.skill_name(entry.stone), 12 if phone else 16, GemMesh.tint(entry.stone).lightened(0.35))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		if bool(entry.get("fresh", false)):
			if phone:
				DeepUi.icon(row, "star", DeepUi.glyph_px(12), StoneCard.PIP_NEW, "A new skill")
			else:
				DeepUi.pill(row, "star", "New skill", StoneCard.PIP_NEW, 12).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			var was: int = int(DeepStone.grade(entry.was).score)
			var now: int = int(DeepStone.grade(entry.stone).score)
			DeepUi.label(row, "%d → %d" % [was, now], 11 if phone else 15, DeepUi.GOOD if now > was else DeepUi.MUTED)
		if not _instant:
			DeepUi.pop_in(row, 0.25 + 0.06 * float(index), 0.9, 0.3)
	if list.size() > room:
		DeepUi.label(box, "+%d more" % (list.size() - room + 1), 11 if phone else 14, DeepUi.MUTED)

func _report_gold(parent: Control, width: float) -> void:
	var phone: bool = DeepUi.phone
	var card := DeepUi.card(parent, Color(DeepUi.ACCENT, 0.3), int(DeepUi.pt(5)) if phone else 16)
	if width > 0.0:
		card.custom_minimum_size.x = width
	else:
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(card, int(DeepUi.pt(1)) if phone else 6)
	DeepUi.section(box, "coins", "The gold", DeepUi.ACCENT, 11 if phone else 15)
	DeepUi.label(box, "The haul is worth", 11 if phone else 14, DeepUi.MUTED)
	var worth: int = int(report.get("worth", 0))
	var big := DeepUi.title(box, DeepUi.number(worth), 26 if phone else 56, DeepUi.ACCENT_HI)
	big.add_theme_font_override("font", DeepUi.bold_font())
	if not _instant and worth > 0:
		big.text = "0"
		var count := big.create_tween()
		count.tween_interval(0.35)
		count.tween_method(func(v: float) -> void: big.text = DeepUi.number(int(round(v))), 0.0, float(worth), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var lines: Array = []
	var kept_worth: int = 0
	for entry in report.get("kept", []):
		kept_worth += DeepStone.value(entry.stone)
	if kept_worth > 0 and not phone:
		DeepUi.label(box, "%s kept, worth %s" % [DeepUi.plural(report.get("kept", []).size(), "stone"), DeepUi.number(kept_worth)], 13, DeepUi.DIM)
	var sold: Array = report.get("sold", [])
	if not sold.is_empty():
		var paid: int = 0
		for entry in sold:
			paid += int(entry.get("paid", 0))
		lines.append(["scales", ("Sold %d" if phone else "Sold %s") % ([sold.size()] if phone else [DeepUi.plural(sold.size(), "stone")]), "+%s" % DeepUi.number(paid), DeepUi.PAPER])
	for entry in report.get("turned", []):
		var turned: String = "Commission" if phone else "%s, to a commission" % DeepUi.skill_name(entry.stone)
		lines.append(["flag", turned, "+%s" % DeepUi.number(int(entry.paid)), DeepUi.PAPER])
	if int(report.get("fees", 0)) > 0:
		lines.append(["coin", "Reading fees", "−%s" % DeepUi.number(int(report.fees)), DeepUi.BAD])
	for entry in lines:
		var row := DeepUi.hbox(box, int(DeepUi.pt(3)) if phone else 8)
		if not phone:
			DeepUi.icon(row, str(entry[0]), 16, DeepUi.MUTED)
		DeepUi.label(row, str(entry[1]), 11 if phone else 15, DeepUi.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := DeepUi.label(row, str(entry[2]), 11 if phone else 15, entry[3])
		value.add_theme_font_override("font", DeepUi.bold_font())
	DeepUi.spacer(box, false)
	var purse := DeepUi.hbox(box, 6)
	DeepUi.label(purse, "Purse", 11 if phone else 15, DeepUi.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sum := DeepUi.label(purse, "%s → %s" % [DeepUi.number(int(report.get("purse_from", 0))), DeepUi.number(int(report.get("purse_to", 0)))] if not phone else DeepUi.number(int(report.get("purse_to", 0))), 11 if phone else 16, DeepUi.PAPER)
	sum.add_theme_font_override("font", DeepUi.bold_font())

func _report_foot(kept: Array, best: Dictionary) -> void:
	var phone: bool = DeepUi.phone
	var foot := DeepUi.card(self, Color(DeepUi.LINE, 0.9), int(DeepUi.pt(4)) if phone else 12, Color(0.045, 0.055, 0.09, 0.95))
	var row := DeepUi.hbox(foot, int(DeepUi.pt(6)) if phone else 18)
	row.custom_minimum_size.y = DeepUi.pt(44) if phone else 52.0
	if not phone:
		DeepUi.icon(row, "chest", 32, StoneCard.PIP_NEW)
	var meter_box := DeepUi.vbox(row, int(DeepUi.pt(2)) if phone else 4)
	meter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var total: int = maxi(1, DeepProfile.known_skills(profile()).size())
	var from: int = int(report.get("vault_from", 0))
	var to: int = int(report.get("vault_to", from))
	var fresh: int = kept.filter(func(e: Dictionary) -> bool: return bool(e.get("fresh", false))).size()
	var upgraded: int = kept.size() - fresh
	var words := DeepUi.hbox(meter_box, int(DeepUi.pt(3)) if phone else 8)
	DeepUi.label(words, "Vault %d of %d" % [to, total], 12 if phone else 17, DeepUi.PAPER).add_theme_font_override("font", DeepUi.bold_font())
	if fresh > 0:
		DeepUi.label(words, "+%d new" % fresh, 11 if phone else 15, StoneCard.PIP_NEW)
	if upgraded > 0 and not phone:
		DeepUi.label(words, "· %s" % DeepUi.plural(upgraded, "upgrade"), 15, DeepUi.MUTED)
	var meter := DeepUi.bar(meter_box, DeepUi.pt(6) if phone else 12.0, DeepUi.ACCENT, Color(DeepUi.INK, 0.9))
	meter.custom_minimum_size.x = DeepUi.pt(200) if phone else 520.0
	meter.call("set_values", float(from) / float(total))
	if not _instant and to > from:
		var fill := meter.create_tween()
		fill.tween_interval(0.6)
		fill.tween_method(func(v: float) -> void: meter.call("set_values", v), float(from) / float(total), float(to) / float(total), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not phone:
		var next: int = 0
		for mark in DeepProfile.VAULT_MILESTONES:
			if to < int(mark):
				next = int(mark)
				break
		if next > 0:
			DeepUi.label(meter_box, "%d to go to %d" % [next - to, next], 12, DeepUi.DIM)
	DeepUi.spacer(row)
	var skill: String = str(best.get("skill", ""))
	if not best.is_empty() and profile().get("vault", {}).has(skill):
		var starred: bool = DeepProfile.favorites(profile()).has(skill)
		var star_words := func(on: bool) -> String:
			if phone:
				return "Starred" if on else "Star it"
			return ("%s is starred" if on else "Star %s") % DeepUi.skill_name(best)
		var star := DeepUi.icon_button(row, "star", star_words.call(starred), Callable(), 12 if phone else 16, DeepUi.ACCENT_HI)
		star.pressed.connect(func() -> void:
			var on: bool = DeepProfile.toggle_favorite(profile(), skill)
			home.touch()
			DeepAudio.play("star", {"volume": 0.8})
			star.text = star_words.call(on)
			DeepUi.pulse(star, 1.12, 0.3)
			if on and star.is_inside_tree():
				DeepUi.burst(star, star.size * 0.5, DeepUi.ACCENT_HI, 24, 160.0, 0.6, 5.0))
		star.name = "StarBest"
		star.custom_minimum_size = Vector2(DeepUi.pt(80), DeepUi.pt(44)) if phone else Vector2(0, 50)
		if not phone:
			star.tooltip_text = "Starred stones lead your showcase, which the party sees"
	var go := DeepUi.primary(row, "anvil" if holding else "chest", ("Into the workshop" if holding else "Back to the vault"), finish, 13 if phone else 19)
	go.name = "IntoWorkshop"
	go.custom_minimum_size = Vector2(DeepUi.pt(150), DeepUi.pt(44)) if phone else Vector2(300, 54)
	if not _instant:
		DeepUi.breathe(go, 0.85, 1.8)

func finish() -> void:
	## Out of the haul: the workshop opens (or the vault's collection), the table is let go.
	profile().erase("haul")
	profile().erase("haul_report")
	if holding:
		profile().erase("homecoming")
		home._appraise_pick = ""
		home.open("descend", false, false)
	else:
		home._vault_view = "collection"
	home.let_go_kept("haul_")
	home.profile_changed.emit()

# --- the fate menu, and keys ------------------------------------------------------------------------

func open_menu(id: String, chip: Control) -> void:
	## A card's fate clicked on the desk: its fates in a little list under it, 1 to 4 to pick.
	_close_menu()
	focus_on(id)
	var stone: Dictionary = _stone(id)
	var offered: Array = DeepProfile.fates_for(profile(), stone, stones)
	if offered.size() < 2 or DeepUi.phone:
		return
	var catcher := Control.new()
	catcher.top_level = true
	catcher.z_index = 50
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.position = Vector2.ZERO
	catcher.size = get_viewport_rect().size
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_menu())
	add_child(catcher)
	var menu := DeepUi.card(catcher, DeepUi.ACCENT, 8, Color(0.05, 0.065, 0.11, 0.98))
	var box := DeepUi.vbox(menu, 4)
	for index in range(offered.size()):
		var fate: String = str(offered[index])
		var look: Array = fate_look(fate)
		var price: int = _price(stone, fate)
		var on: bool = str(fates.get(id, "")) == fate
		var choice := DeepUi.icon_button(box, str(look[0]), "%s%s" % [str(look[1]), ("  +%d" % price) if price > 0 else ""], func() -> void:
			_close_menu()
			set_fate(id, fate), 14, look[3])
		choice.custom_minimum_size = Vector2(230, 38)
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if on:
			DeepUi.selected_style(choice, look[3])
		choice.tooltip_text = "Press %d" % (index + 1)
	var at: Vector2 = chip.global_position + Vector2(0, chip.size.y + 4)
	menu.position = Vector2(clampf(at.x - 60, 8, catcher.size.x - 250), clampf(at.y, 8, catcher.size.y - 60 - 44 * offered.size()))
	_menu = catcher
	DeepUi.pop_in(menu, 0.0, 0.92, 0.16)

func _close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null

func _unhandled_key_input(event: InputEvent) -> void:
	## Space cracks, Enter settles (or goes into the workshop), the arrows move along the cards,
	## 1 to 4 choose the pointed-at stone's fate, Page Up and Down turn the grid's pages.
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if Inspector.is_open() or Spotlight.is_open() or Geode.is_open():
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_ESCAPE and _menu != null:
		_close_menu()
	elif key == KEY_SPACE and phase == "laid":
		crack_all()
	elif key in [KEY_ENTER, KEY_KP_ENTER]:
		if phase == "fates":
			settle()
		elif phase == "report":
			finish()
		elif phase == "laid":
			crack_all()
	elif key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and _grid != null:
		var on_page: Array = DeepUi.page_of(order, page, _per_page())
		var at: int = maxi(0, on_page.find(focus))
		var step: int = {KEY_LEFT: -1, KEY_RIGHT: 1, KEY_UP: -_grid.cols, KEY_DOWN: _grid.cols}[key]
		var to: int = at + step
		if to >= 0 and to < on_page.size():
			focus_on(str(on_page[to]))
	elif key >= KEY_1 and key <= KEY_5 and phase == "fates":
		var offered: Array = DeepProfile.fates_for(profile(), _stone(focus), stones)
		var index: int = key - KEY_1
		if index < offered.size():
			_close_menu()
			set_fate(focus, str(offered[index]))
	elif key in [KEY_PAGEUP, KEY_PAGEDOWN]:
		turn_page(page + (1 if key == KEY_PAGEDOWN else -1))
	else:
		return
	get_viewport().set_input_as_handled()

# --- the grid and its cards ------------------------------------------------------------------------

class Grid extends Control:
	## The cards laid in rows that fill the room: as many across as a haul of this size wants,
	## each no bigger than a card should be, the block centred. Cards slide when they move.
	var cards: Array = []
	var cols: int = 6
	var rows: int = 3
	var gap: float = 10.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		clip_contents = false
		gap = DeepUi.pt(4) if DeepUi.phone else 10.0

	func shape(count: int) -> void:
		## Columns from the count: three for a few, six for eighteen, eight for thirty-two, ten
		## for fifty. The phone stops at six.
		cols = clampi(ceili(sqrt(float(maxi(1, count)) * 1.7)), 3, 6 if DeepUi.phone else 10)
		rows = maxi(1, ceili(float(count) / float(cols)))
		if DeepUi.phone:
			rows = maxi(rows, 1)

	func compact() -> bool:
		## Small cards keep to the gem, its name, its grade and its fate.
		if DeepUi.phone:
			return true
		return cols >= 8 or rows >= 4

	func cell(index: int) -> Rect2:
		var cap: Vector2 = Vector2(DeepUi.pt(92), DeepUi.pt(112)) if DeepUi.phone else Vector2(250.0, 310.0)
		var cw: float = minf((size.x - gap * float(cols - 1)) / float(cols), cap.x)
		var ch: float = minf((size.y - gap * float(rows - 1)) / float(rows), cap.y)
		var block := Vector2(cw * float(cols) + gap * float(cols - 1), ch * float(rows) + gap * float(rows - 1))
		var origin := Vector2(maxf(0.0, (size.x - block.x) * 0.5), maxf(0.0, (size.y - block.y) * 0.5) if rows <= 2 else 0.0)
		return Rect2(origin + Vector2(float(index % cols) * (cw + gap), float(index / cols) * (ch + gap)), Vector2(cw, ch))

	func place(animated: bool) -> void:
		for index in range(cards.size()):
			var card: Control = cards[index]
			if not is_instance_valid(card):
				continue
			var rect: Rect2 = cell(index)
			if animated and not DeepUi.headless():
				var tween := card.create_tween()
				tween.set_parallel(true)
				tween.tween_property(card, "position", rect.position, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				tween.tween_property(card, "size", rect.size, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			else:
				card.position = rect.position
				card.size = rect.size

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			place(false)

class Card extends PanelContainer:
	## One stone on the table: its verdict along the top, the stone (in its rock until it is
	## cracked), its name, its carat and Cut, its grade, and the fate it is set for.
	var table: Control
	var id: String = ""
	var compact: bool = false
	var _style: StyleBoxFlat
	var _ribbon: HBoxContainer
	var _ribbon_mark: TextureRect
	var _ribbon_words: Label
	var _art: Control
	var _glow: TextureRect
	var _thumb: Control
	var _cracks: Cracks
	var _name: Label
	var _sub: Label
	var _grade_row: HBoxContainer
	var _fate_row: HBoxContainer
	var _focused: bool = false
	var _stone: Dictionary = {}

	func _init(owner: Control, stone_id: String, small: bool) -> void:
		table = owner
		id = stone_id
		compact = small
		name = "Card_" + stone_id
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		clip_contents = false
		var pad: int = int(DeepUi.pt(3)) if DeepUi.phone else (6 if compact else 8)
		_style = DeepUi.flat(Color(0.055, 0.075, 0.13, 0.96), Color(DeepUi.LINE, 0.9), 10, pad, 1)
		add_theme_stylebox_override("panel", _style)
		var box := DeepUi.vbox(self, 1 if DeepUi.phone else 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ribbon = DeepUi.hbox(box, 4)
		_ribbon.custom_minimum_size.y = 0.0 if compact else 18.0
		_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ribbon_mark = DeepUi.icon(_ribbon, "star", DeepUi.glyph_px(11) if DeepUi.phone else 14.0, DeepUi.MUTED)
		_ribbon_words = DeepUi.label(_ribbon, "", 12, DeepUi.MUTED)
		_ribbon_words.clip_text = true
		_ribbon_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ribbon.modulate.a = 0.0
		_art = Control.new()
		_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_art.custom_minimum_size.y = DeepUi.pt(24) if DeepUi.phone else 30.0
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.resized.connect(_fit_art)
		box.add_child(_art)
		_glow = DeepUi.glow(_art, Color.WHITE, 0.0, 1.0)
		_glow.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_thumb = Thumbs.GemThumb.new({}, 32.0)
		_art.add_child(_thumb)
		_cracks = Cracks.new()
		_art.add_child(_cracks)
		if compact:
			## A small card wears its verdict as a mark in the corner of the picture.
			box.remove_child(_ribbon)
			_art.add_child(_ribbon)
			_ribbon.position = Vector2.ZERO
			_ribbon_words.visible = false
		_name = DeepUi.label(box, "", 11 if DeepUi.phone else (13 if compact else 15), DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		_name.clip_text = true
		_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name.custom_minimum_size.x = 0.0
		_name.add_theme_font_override("font", DeepUi.bold_font())
		_sub = DeepUi.label(box, "", 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_sub.clip_text = true
		_sub.visible = not compact
		_grade_row = DeepUi.hbox(box, int(DeepUi.pt(2)) if DeepUi.phone else 4)
		_grade_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_grade_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grade_row.custom_minimum_size.y = DeepUi.pt(16) if DeepUi.phone else (22.0 if compact else 24.0)
		if compact:
			_fate_row = _grade_row
		else:
			_fate_row = DeepUi.hbox(box, 4)
			_fate_row.alignment = BoxContainer.ALIGNMENT_CENTER
			_fate_row.custom_minimum_size.y = 26.0
		_fate_row.mouse_filter = Control.MOUSE_FILTER_PASS
		gui_input.connect(_input_on)
		Tips.hold(self, func() -> Variant:
			if _stone.is_empty():
				return false
			Inspector.stone(_stone)
			return true)

	func _input_on(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				table.focus_on(id)
			elif event.button_index == MOUSE_BUTTON_RIGHT and not _stone.is_empty():
				Inspector.stone(_stone)
				accept_event()

	func _fit_art() -> void:
		if compact:
			_ribbon.position = Vector2.ZERO
			_ribbon.size = _ribbon.get_combined_minimum_size()
		var edge: float = minf(_art.size.x, _art.size.y)
		if not bool(_stone.get("appraised", true)) and not DeepStone.is_geode(_stone):
			edge *= 1.3
		_thumb.size = Vector2(edge, edge)
		_thumb.position = (_art.size - _thumb.size) * 0.5
		var light: float = edge * 1.7
		_glow.size = Vector2(light, light)
		_glow.position = (_art.size - _glow.size) * 0.5
		_cracks.size = _thumb.size
		_cracks.position = _thumb.position

	func show_stone(stone: Dictionary, open: bool) -> void:
		## The stone as the card shows it: its name and its carat and Cut once read; its size
		## class (or the Geode's carats) before.
		_stone = stone
		_thumb.call("configure", stone)
		if _art.size.x > 0.0:
			_fit_art()
		if open:
			_name.text = DeepUi.skill_name(stone)
			_name.add_theme_color_override("font_color", GemMesh.tint(stone).lightened(0.35))
			_sub.text = "%d ct · %s" % [int(stone.get("carat", 1)), DeepContent.cut_name(int(stone.get("cut", 0)))]
		else:
			_name.text = (str(DeepStone.size_class(int(stone.get("carat", 1))).name) if not DeepStone.is_geode(stone) else "Geode") if DeepUi.phone else DeepStone.raw_name(stone)
			_name.add_theme_color_override("font_color", DeepUi.MUTED)
			if DeepStone.is_geode(stone):
				var carats: Array = DeepEconomy.geode_odds(stone.geode).get("carat", [1, 1])
				_sub.text = "%d–%d ct inside" % [int(carats[0]), int(carats[1])]
			else:
				_sub.text = str(DeepStone.size_class(int(stone.get("carat", 1))).range)
		_name.tooltip_text = _name.text

	func set_focus(on: bool) -> void:
		_focused = on
		var style: StyleBoxFlat = _style.duplicate()
		if on:
			style.border_color = DeepUi.ACCENT
			style.set_border_width_all(2)
			style.shadow_color = Color(DeepUi.ACCENT, 0.3)
			style.shadow_size = 10
		add_theme_stylebox_override("panel", style)

	func set_ribbon(glyph: String, words: String, tone: Color) -> void:
		_ribbon_mark.texture = load("res://view/gems/gem_icons.gd").texture(glyph, 64)
		_ribbon_mark.modulate = tone
		_ribbon_words.text = words
		_ribbon_words.add_theme_color_override("font_color", tone)
		_ribbon.tooltip_text = words
		_ribbon.modulate.a = 1.0

	func set_rough(on: bool, paid: int) -> void:
		## Set aside to be sold rough: said on the card, its fate shown early.
		if on:
			set_ribbon("scales", "Sell rough", DeepUi.TRADE)
			set_fate("scales", "Sell rough", "Rough", paid, DeepUi.TRADE, false)
		else:
			_ribbon.modulate.a = 0.0
			clear_fate()

	func set_grade(on: bool) -> void:
		for child in _grade_row.get_children():
			if child.has_meta("grade"):
				child.queue_free()
		if not on or _stone.is_empty():
			return
		var grade: Dictionary = DeepStone.grade(_stone)
		var tone: Color = DeepUi.tier_color(str(grade.tier))
		var said: String = "Grade %d of 100, %s" % [int(grade.score), str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier))]
		var pill: Control
		if DeepUi.phone:
			## The phone's card has room for the number in its tier's color and the fate's mark.
			pill = DeepUi.stat(_grade_row, "star", str(int(grade.score)), tone, 11, said)
		else:
			var words: String = str(int(grade.score)) if compact else "%d %s" % [int(grade.score), str(DeepStone.TIER_NAMES.get(str(grade.tier), grade.tier))]
			pill = DeepUi.pill(_grade_row, "star", words, tone, 12, said)
		pill.set_meta("grade", true)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_grade_row.move_child(pill, 0)

	func set_fate(glyph: String, words: String, short: String, price: int, tone: Color, risky: bool) -> void:
		clear_fate()
		var shown: String = words
		if DeepUi.phone:
			shown = ""
		elif compact:
			shown = ("+%d" % price) if price > 0 else short
		elif price > 0:
			shown = "%s +%d" % [words, price]
		var chip := DeepUi.pill(_fate_row, glyph, shown, DeepUi.BAD if risky else tone, 11 if DeepUi.phone else 12, ("%s · gives up the finer stone" % words) if risky else words)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.set_meta("fate", true)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				table.open_menu(id, chip)
				chip.accept_event())

	func clear_fate() -> void:
		for child in _fate_row.get_children():
			if child.has_meta("fate"):
				child.queue_free()

	func crack(tone: Color, strength: float) -> void:
		## The rock shakes and light of its grade leaks out through the cracks.
		_cracks.tone = tone
		_cracks.strength = strength
		_cracks.visible = true
		_glow.modulate = Color(tone, 0.0)
		var tween := create_tween()
		tween.tween_property(_glow, "modulate:a", 0.25 + 0.6 * strength, 0.14)
		tween.parallel().tween_property(_cracks, "reveal", 1.0, 0.14)
		DeepUi.shake(_thumb, 3.0 + 3.0 * strength, 0.16)

	func open_up(known: Dictionary, tone: Color, rank: int) -> void:
		## The rock splits away in a spray and the gem shows.
		show_stone(known, true)
		_cracks.visible = false
		_cracks.reveal = 0.0
		var tween := create_tween()
		tween.tween_property(_glow, "modulate:a", 0.12 + 0.07 * float(rank), 0.6)
		_thumb.pivot_offset = _thumb.size * 0.5
		_thumb.scale = Vector2.ONE * 0.5
		var pop := _thumb.create_tween()
		pop.tween_property(_thumb, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if is_inside_tree():
			var heart: Vector2 = _art.position + _thumb.position + _thumb.size * 0.5
			DeepUi.burst(self, heart, tone.lightened(0.3), 14 + 10 * rank, 120.0 + 50.0 * float(rank), 0.6, 4.0 + float(rank))
			if rank >= 3:
				DeepUi.burst(self, heart, Color.WHITE, 16, 160.0, 0.6, 4.0)

	func stamp() -> void:
		## The grade drops onto the card large and lands.
		set_grade(true)
		for child in _grade_row.get_children():
			if child.has_meta("grade") and not child.is_queued_for_deletion():
				var pill: Control = child
				pill.modulate.a = 0.0
				var land := pill.create_tween()
				land.tween_interval(0.0)
				land.tween_callback(func() -> void:
					pill.pivot_offset = pill.size * 0.5
					pill.scale = Vector2.ONE * 2.1
					pill.rotation = -0.14)
				land.tween_property(pill, "modulate:a", 1.0, 0.06)
				land.parallel().tween_property(pill, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				land.parallel().tween_property(pill, "rotation", 0.0, 0.2)

	func flourish() -> void:
		## The verdict and fate coming on after the slide.
		_ribbon.modulate.a = 0.0
		_ribbon.create_tween().tween_property(_ribbon, "modulate:a", 1.0, 0.25)
		for child in _fate_row.get_children():
			if child.has_meta("fate"):
				DeepUi.pop_in(child, 0.0, 0.7, 0.25)

	func seal() -> void:
		## A commission's wax seal, pressed onto the card.
		var mark := Seal.new()
		var edge: float = minf(size.x, size.y) * 0.5
		mark.size = Vector2(edge, edge)
		mark.position = (size - mark.size) * 0.5
		mark.pivot_offset = mark.size * 0.5
		mark.scale = Vector2.ONE * 2.4
		mark.modulate.a = 0.0
		mark.z_index = 5
		add_child(mark)
		var tween := mark.create_tween()
		tween.tween_property(mark, "modulate:a", 1.0, 0.08)
		tween.parallel().tween_property(mark, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		DeepAudio.play("contract_seal", {"volume": 0.8, "gap": 0.05})

class Cracks extends Control:
	## Lines of light across a rock about to split, in its grade's color.
	var tone: Color = Color.WHITE
	var strength: float = 0.5
	var reveal: float = 0.0:
		set(value):
			reveal = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		if reveal <= 0.0:
			return
		var w: float = size.x
		var h: float = size.y
		var main := PackedVector2Array([Vector2(w * 0.5, h * 0.12), Vector2(w * 0.44, h * 0.38), Vector2(w * 0.56, h * 0.56), Vector2(w * 0.46, h * 0.86)])
		var branch := PackedVector2Array([Vector2(w * 0.56, h * 0.56), Vector2(w * 0.74, h * 0.5)])
		var shown := PackedVector2Array()
		var count: int = maxi(2, int(ceil(float(main.size()) * reveal)))
		for index in range(mini(count, main.size())):
			shown.append(main[index])
		var width: float = maxf(1.5, w * (0.018 + 0.02 * strength))
		draw_polyline(shown, Color(tone, 0.35), width * 3.0, true)
		draw_polyline(shown, Color(tone.lightened(0.5), 0.95), width, true)
		if reveal > 0.6 and strength > 0.6:
			draw_polyline(branch, Color(tone.lightened(0.4), 0.8), width * 0.8, true)

class Seal extends Control:
	## A red wax seal with a flag pressed into it.
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		draw_circle(centre, radius, Color("7a1f16"))
		draw_circle(centre, radius * 0.86, Color("c0392b"))
		draw_arc(centre, radius * 0.86, 0.0, TAU, 40, Color("e7604f"), maxf(1.0, radius * 0.08), true)
		var flag: Texture2D = load("res://view/gems/gem_icons.gd").texture("flag", 64)
		if flag != null:
			var edge: float = radius * 1.0
			draw_texture_rect(flag, Rect2(centre - Vector2(edge, edge) * 0.5, Vector2(edge, edge)), false, Color("ffd9cf"))
