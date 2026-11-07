extends Control
## What the party carries, always at hand outside a fight: the rail and the five dice along
## the bottom of the screen, where the fight's dock stands when there is a fight, and the bag
## as a column down the right edge of the screen, opposite the chart (opened from the bag on
## the strip, or B): the sort as a drop-down and the color dots at its top, the stones in tiles
## two across under them, turned a page at a time, never scrolled, and the stone last pointed
## at read on a plate beside it. The dock stands as tall as the fight's dock and draws its
## stones and dice as large, so nothing at the bottom of the screen jumps when a fight begins
## or ends. The bag never moves the dock: it lies over the right edge of the room, from under
## the strip down to the dock and the party's tabs, the way the chart lies over the left, and
## wears the chart's plate (the owner, Nov 6, 2026). In a party the seat tabs stand on the dock
## too, each saying whether that player is still choosing, done, down or away.
##
## Everything is moved by dragging. A stone from the bag onto a socket sets it; a set stone
## into the bag takes it out; one of the five dice onto another changes their places (the
## five are the five a player came down with: dice are worked in the mine, never swapped).
## At a stall the stones on the counter drag straight onto a socket or the bag, which buys
## them (and sets them), and a stone from the bag drags onto the lens or the scales in the
## room. A Void gem takes no socket: dropped on one it rides it, in a line of chips under the
## socket's name, and fires right after the socket's own gem; dropped on another rider it
## goes into the line ahead of that one. Right-click anything for the close look. Nothing
## here decides anything: it asks, and the run answers.

const Thumbs = preload("res://view/gems/thumbs.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Inspector = preload("res://view/inspect/inspector.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const ShaftMap = preload("res://view/run/shaft_map.gd")
const EffectChips = preload("res://view/battle/effect_chips.gd")
const Roster = preload("res://view/home/roster.gd")
const VitalsRing = preload("res://view/battle/vitals_ring.gd")
const Fan = preload("res://view/battle/fan.gd")
const Tips = preload("res://view/ui/tips.gd")
const Plates = preload("res://view/ui/plates.gd")
const StoneBrowser = preload("res://view/home/stone_browser.gd")

signal command(cmd: Dictionary)
signal drawer_toggled(open: bool)
signal chose(id: String)
## A thing on the dock clicked while the ask lights it: `kind` is "stone" or "die".
signal picked(kind: String, id: String)
## Another player's tab clicked at a landing, where it opens a trade with them.
signal trade_with(id: String)

## A socket and a die are as large as the fight's dock draws them (BattleScreen.SOCKET_EDGE,
## DIE_EDGE; a die there has its number under it, which this one has not).

## A Void gem riding a socket, and how many of them show at this size before a count.
const RIDER := 18.0
const RIDERS_SHOWN := 3
## The least the dock stands, before it is told how tall the fight's dock is (`dock_height`).
const DOCK_HEIGHT := 150.0
## A stone's tile in the bag column (the run bench's size), the gap between tiles, and both.
## A tile is drawn between `GEM_TILE_LEAST` and `GEM_TILE`: as many rows as fit at the least,
## then grown to fill the column's height, so no band of empty rock stands under the last row
## (the owner, Nov 6, 2026: five rows of 70 px at 1600 × 900, ten stones a page).
const GEM_TILE := 72.0
const GEM_TILE_LEAST := 64.0
const GEM_TILE_GAP := 6.0
const GEM_TILE_STEP := GEM_TILE + GEM_TILE_GAP
## The room between the column's rows (toolbar, toggles, tiles, foot).
const COLUMN_ROW_GAP := 4
## The bag column: tiles two across; what stands inside its plate (the row of toggles wants
## 186 at the text floor, more than the two tiles); the plate's own padding (`DeepUi.ledger`,
## 12 a side); and the gap it keeps from the screen's edge. `COLUMN_WIDTH` is the whole plate.
const COLUMN_COLUMNS := 2
const COLUMN_INNER := 190.0
const COLUMN_PAD := 12.0
const COLUMN_WIDTH := COLUMN_INNER + COLUMN_PAD * 2.0
const COLUMN_GAP := 8.0
const COLUMN_TOP := 6.0
## Whether the column runs over the dock to the foot of the screen (round 3, Nov 5, 2026) or,
## false, stands its foot above the dock and the party's tabs, as the chart's does
## (descent_screen.gd `_fit_area`): the owner, Nov 6, 2026, "extend only the vertical space
## above the hotbar ... so its height ends before overlapping the dice area".
const COLUMN_OVER_DOCK := false
## The row at the column's foot: the pager, or a word on reading a stone.
const FOOT_ROW := 30.0
## The sorts the bag offers, of the vault's (StoneBrowser.SORTS): not when or where a stone
## was found, which down the mine is this run.
const BAG_SORTS: Array = ["grade", "carat", "cut", "clarity", "worth", "rarity", "color", "name"]
## The reading plate beside the column: the stone last pointed at, and what can be done with it.
const PANE_WIDTH := 250.0
const PANE_HEIGHT := 140.0
## The phone's bag (board run-bag): its width inside the screen's safe edge, its stones four a
## row between two sizes, and the card at its foot that reads the stone tapped (points).
const PHONE_COLUMN := 290.0
const PHONE_COLUMNS := 4
const PHONE_TILE := Vector2(50.0, 64.0)
const PHONE_CARD := 124.0
## What stands inside the phone's panel, its padding (COLUMN_PAD a side) taken off.
const PHONE_INNER := PHONE_COLUMN - COLUMN_PAD

var local_id: String = ""
var run: Dictionary = {}
## How tall the fight's dock stands, so this one stands the same (the descent screen sets it).
var dock_height: float = 0.0:
	set(value):
		dock_height = value
		_fit_dock()
## () -> Control: the bag on the strip, where a stone flies to and from now that the dock has
## no bag of its own.
var bag_anchor: Callable = Callable()
var _dock: PanelContainer
## The party's seat tabs over the dock: by player id.
var _tab_bar: HBoxContainer = null
var _tabs: Dictionary = {}
## How tall the dock stands now.
var _height: float = DOCK_HEIGHT
## The bag column (kept under its old name: it was a drawer over the dock until Nov 5, 2026).
var _drawer: PanelContainer
## The tiles on the column's current page, two across.
var _tiles: GridContainer = null
## The reading plate beside the column, and the box inside it that `_fill_pane` fills.
var _pane: PanelContainer = null
var _pane_box: VBoxContainer = null
var _open: bool = false
## The stone browser's settings and page numbers (view/home/stone_browser.gd keeps them on
## whoever hosts its toolbar): the bag's sort, direction and color dots live in
## `browse["bag"]` and `browse["_sort"]`, and the page the column is turned to in
## `_pages["bag_page"]`, which the browser resets whenever the sort or a filter changes.
var browse: Dictionary = {}
var _pages: Dictionary = {}
## The bag was opened by an ask's spotlight, not by the player: it shuts again with the ask, or
## it would stand over the page the ask's answer opens (and that page's Onward).
var _ask_opened: bool = false
## The bag was opened by a drag off a stall's counter: it shuts again when the drag ends.
var _drag_opened: bool = false
## What the bag shows (docs/UI_REDO.md): appraised stones and raw ones by default, Geodes
## only when asked; only what fits a socket, when asked. The sort is the browser's (`sort_by`
## reads and sets it, for whoever still speaks of the bag's sort by name).
var show_appraised: bool = true
var show_raw: bool = true
var show_geodes: bool = false
## No Fits filter (removed by the owner, November 6, 2026, round 9): the bag shows every stone
## its toggles allow.
var sort_by: String:
	get:
		return str(StoneBrowser.settings(self, "bag").sort)
	set(value):
		StoneBrowser.settings(self, "bag")
		browse["_sort"].sort = value
## The stone the drawer's reading pane is open on (the last one pointed at).
var _reading: String = ""
var _key: String = ""
var _targets: Array = []
## A choice waiting on one of the things the player carries: {kind, items, prompt}. It is
## asked on the ask sheet (ask_sheet.gd), which the screen that owns this dock sets here.
var _offer: Dictionary = {}
var ask: Control = null:
	set(value):
		ask = value
		if ask != null:
			ask.confirmed.connect(_ask_answered)
			ask.cancelled.connect(func() -> void: _offer = {})
## What the ask lights on the dock: {"stone": [ids], "die": [ids]}; empty for nothing.
var _spot: Dictionary = {}
## Where each thing stands in the dock as last drawn, by kind and id ("stone", "die",
## "socket", "bag", "dice"), so a flourish can fly something out of it or into it.
var _spots: Dictionary = {}
## The health ring, its (health, most) as drawn, and the cost a pointed-at click would take.
var _ring: VitalsRing = null
var _ring_hp: Vector2i = Vector2i.ZERO
var _hp_cost: int = 0
## Stones drawn but not yet shown: a gem the Hollow made Void is on the rail before the rite
## that put it there has finished, and stays out of sight until it lands.
var _veiled: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## The bag column, down the right edge; `_fit_dock` sets where its foot stands.
	_drawer = PanelContainer.new()
	_drawer.name = "Bag"
	## The chart's plate (`ShaftMap.side_plate`), its shadow falling to the left over the room.
	var plate: StyleBoxFlat = ShaftMap.side_plate(-1.0, int(COLUMN_PAD))
	## On the phone the panel runs to the screen's edge, its stones inside the safe edge.
	if DeepUi.phone:
		plate.content_margin_right += DeepUi.safe_right
		plate.content_margin_bottom += DeepUi.safe_bottom
	_drawer.add_theme_stylebox_override("panel", plate)
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	## Anything wider than the column (a larger text floor) grows it left, never off the screen.
	_drawer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_drawer.offset_left = - 16.0 - COLUMN_WIDTH
	_drawer.offset_right = -16.0
	_drawer.offset_top = COLUMN_TOP
	_drawer.offset_bottom = -14.0
	_drawer.visible = false
	add_child(_drawer)
	## The reading plate, beside the column, over the room: the stone last pointed at.
	_pane = PanelContainer.new()
	_pane.name = "Reading"
	_pane.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ACCENT_DIM, 14, 12, 3, 5))
	_pane.mouse_filter = Control.MOUSE_FILTER_STOP
	_pane.visible = false
	add_child(_pane)
	_pane_box = DeepUi.vbox(_pane, 6)
	_pane_box.name = "Pane"
	_pane_box.custom_minimum_size = Vector2(PANE_WIDTH, PANE_HEIGHT)
	## A window made taller or shorter holds a different number of tiles a page.
	resized.connect(func() -> void:
		if _open and visible and not run.is_empty():
			_key = ""
			show_run.call_deferred(run))
	_dock = PanelContainer.new()
	_dock.add_theme_stylebox_override("panel", DeepUi.phone_bar() if DeepUi.phone else DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.LEDGER_LINE, 14, 12, 3, 5))
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	## On the phone the dock is a bar from edge to edge along the foot, as the fight's is.
	_dock.offset_left = 0 if DeepUi.phone else 16
	_dock.offset_right = 0 if DeepUi.phone else -16
	_dock.offset_bottom = 0 if DeepUi.phone else -14
	_dock.offset_top = (0.0 if DeepUi.phone else -14.0) - _height
	add_child(_dock)
	## The party, along the top of the dock, the way a fight shows it. Alone, nobody.
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 6)
	_tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_bar.visible = false
	add_child(_tab_bar)
	## The column and its reading plate are drawn over the dock and the tabs: the last children.
	move_child(_drawer, get_child_count() - 1)
	move_child(_pane, get_child_count() - 1)

func _process(_delta: float) -> void:
	## The tabs stand on the dock: their bottom edge is its top edge.
	if _tab_bar != null and _tab_bar.visible:
		if _tab_bar.size != _tab_bar.get_combined_minimum_size():
			_tab_bar.reset_size()
		_tab_bar.position = Vector2(_dock.position.x + 18.0, _dock.position.y - _tab_bar.size.y)

func _fit_dock() -> void:
	## As tall as the fight's dock, or as its own stones and dice need if that is more.
	if _dock == null:
		return
	_height = maxf(maxf(DOCK_HEIGHT, dock_height), _dock.get_combined_minimum_size().y)
	_dock.offset_top = (0.0 if DeepUi.phone else -14.0) - _height
	## The bag column stands down the right edge, from under the strip to the top of the dock
	## and the party's tabs (`COLUMN_OVER_DOCK`); the dock itself never moves.
	_drawer.offset_left = - 16.0 - COLUMN_WIDTH
	_drawer.offset_right = -16.0
	_drawer.offset_top = COLUMN_TOP
	_drawer.offset_bottom = -14.0 if COLUMN_OVER_DOCK else - side_foot()
	if DeepUi.phone:
		## The phone's bag stands from under the strip to the foot of the screen, over the
		## dock's dice, as the board has it.
		_drawer.offset_left = - _phone_column()
		_drawer.offset_right = 0.0
		_drawer.offset_bottom = 0.0

func side_foot() -> float:
	## How far above the foot of the screen a panel along the side ends: the bag column's foot,
	## a gap above the dock and the party's tabs. The chart's foot stands here too
	## (descent_screen.gd `_fit_area`), so the two side panels stand the same height.
	return 14.0 + _height + _tabs_lift() + COLUMN_GAP

func column_width() -> float:
	## How much of the right edge of the screen the open bag takes, with its gap; 0 while shut.
	## Whoever lays pages over the room can inset them by this.
	if DeepUi.phone:
		return _phone_column() + COLUMN_GAP if _open else 0.0
	return COLUMN_WIDTH + 16.0 + COLUMN_GAP if _open else 0.0

func _phone_column() -> float:
	## The phone's bag, its safe edge included.
	return DeepUi.pt(PHONE_COLUMN) + DeepUi.safe_right

func _column_height() -> float:
	## How tall the column stands inside its plate, from its offsets (its own size lags a frame).
	if size.y <= 0.0:
		return 0.0
	if DeepUi.phone:
		return size.y - _drawer.offset_top + _drawer.offset_bottom - COLUMN_PAD * 2.0 - DeepUi.safe_bottom
	return size.y - _drawer.offset_top + _drawer.offset_bottom - COLUMN_PAD * 2.0

func _tabs_lift() -> float:
	## In a party the seat tabs stand on the dock: the drawer opens above them, not behind
	## them, so a click on a stone near its foot is not taken by a tab.
	return _tab_bar.get_combined_minimum_size().y if _tab_bar != null and _tab_bar.visible else 0.0

# --- the party's tabs --------------------------------------------------------------------------

func _sync_tabs() -> void:
	## A tab a player, the reader's first: the same tabs a fight stands on its dock, so the
	## party is where it was when a fight ends. Each says what that player is doing here; once
	## this player is done, the room's name also gets a "Waiting for" line. Alone, none.
	if _tab_bar == null:
		return
	var players: Array = run.get("players", [])
	var party: bool = players.size() > 1
	_tab_bar.visible = party
	if not party:
		return
	var present: Dictionary = {}
	for index in range(players.size()):
		var unit: Dictionary = players[index]
		var id: String = str(unit.get("id", ""))
		var mine: bool = id == local_id
		var tab: BattleScreen.SeatTab = _tabs.get(id, null)
		if tab == null or not is_instance_valid(tab):
			tab = BattleScreen.SeatTab.new(mine)
			tab.picked.connect(_tab_clicked.bind(id))
			tab.inspected.connect(_look_at.bind(id))
			_tab_bar.add_child(tab)
			_tabs[id] = tab
		present[id] = true
		var seat: Color = ShaftMap.SEATS[int(unit.get("seat", index)) % ShaftMap.SEATS.size()]
		tab.click_hint = "Click to trade a stone with them. Right-click to look at their rail and bag." if _trades_with(id) else ""
		tab.update(unit, DeepContent.character_title(str(unit.get("character", ""))), seat, mine, seat_status(unit), 0, EffectChips.for_run(unit), true)
		tab.portrait.mood = Roster.resting_mood(unit)
		if mine:
			_tab_bar.move_child(tab, 0)
	for id in _tabs.keys():
		if not present.has(id):
			if is_instance_valid(_tabs[id]):
				_tabs[id].queue_free()
			_tabs.erase(id)

func _trades_with(id: String) -> bool:
	## At a landing another player's tab is where a trade with them starts.
	return id != local_id and str(run.get("phase", "")) == "landing" and DeepDescent.can_trade_with(run, local_id, id)

func _tab_clicked(id: String) -> void:
	if _trades_with(id):
		trade_with.emit(id)
		return
	_look_at(id)

func _look_at(id: String) -> void:
	## Another player's tab opens the close look at them: their rail, their dice, their bag.
	var member: Dictionary = DeepDescent.player(run, id)
	if id != local_id and not member.is_empty():
		Inspector.member(member)

func seat_status(unit: Dictionary) -> Array:
	## What a player is doing in the room the party stands in, as the one mark on their tab:
	## [glyph, tone, words]. Someone who is down has no mark: their whole tab is greyed.
	if bool(unit.get("downed", false)):
		return ["", DeepUi.DIM, "Down until the next landing"]
	## The tab's plate says what being away means here, not only the word.
	if not bool(unit.get("connected", true)):
		return ["wifi", DeepUi.DIM, "Lost connection. The party goes on without them until they are back."]
	var choosing_now := func(words: String) -> Array: return ["hourglass", DeepUi.MUTED, words]
	var done := func(words: String) -> Array: return ["check", DeepUi.GOOD, words]
	var id: String = str(unit.get("id", ""))
	match str(run.get("phase", "")):
		"grubstake":
			return done.call("Has taken a stake") if not str(unit.get("stake", "")).is_empty() else choosing_now.call("Choosing a stake")
		"tunnels":
			return done.call("Has chosen a way on") if not str(unit.get("vote", "")).is_empty() else choosing_now.call("Choosing a way on")
		"chamber":
			var kind: String = str(run.get("chamber", {}).get("kind", ""))
			if kind == "oddity" or kind in DeepDescent.CARD_ROOMS:
				return done.call("Has chosen") if not str(unit.get("oddity_choice", "")).is_empty() else choosing_now.call("Choosing")
			if kind in DeepDescent.ROCK_ROOMS:
				return ["pick", DeepUi.ACCENT, "Still mining"] if bool(unit.get("mining", false)) else done.call("Done mining")
			if kind == "merchant":
				return done.call("Done here") if bool(unit.get("ready", false)) else choosing_now.call("Shopping")
			if kind == "altar":
				return done.call("Done here") if str(unit.get("altar_done", "")) == "left" else choosing_now.call("At the altar")
		"landing":
			match str(unit.get("choice", "")):
				"lift":
					return ["lift", DeepUi.GOOD, "Wants to ride the lift up"]
				"descend":
					return ["descend", DeepUi.ACCENT, "Going on down"]
			## A stone offered to the reader is the mark that matters most: their tab is where
			## the trade is answered.
			var offer: Dictionary = DeepDescent.trade_offer_of(run, id)
			if id != local_id and str(offer.get("to", "")) == local_id and DeepDescent.can_trade_with(run, local_id, id):
				return ["scales", DeepUi.ORE, "Offers you a stone: click to answer"]
			var station: String = str(unit.get("station", ""))
			if station == "trade" or not offer.is_empty():
				var with_id: String = str(offer.get("to", ""))
				var with_name: String = "you" if with_id == local_id else str(DeepDescent.player(run, with_id).get("name", ""))
				return ["scales", DeepUi.ORE, ("Trading with %s" % with_name) if not with_id.is_empty() else "Trading"]
			if DeepDescent.needs_respite(run, unit):
				## At the camp, still to take a respite: where they stand, if anywhere.
				if SEAT_STATIONS.has(station):
					return [SEAT_STATIONS[station][0], DeepUi.MUTED, str(SEAT_STATIONS[station][1])]
				return choosing_now.call("Taking a respite")
			if not DeepDescent.at_crossroads(run):
				## Done at the camp, waiting on the rest: what they did.
				var took: String = str(unit.get("respite", ""))
				return done.call(str(SEAT_DONE.get(took, "Done here")))
			if station == "up":
				return [SEAT_STATIONS.up[0], DeepUi.MUTED, str(SEAT_STATIONS.up[1])]
			return choosing_now.call("Choosing the way on")
		"hoard":
			var pile: Dictionary = run.get("hoard", {}).get(id, {})
			if not pile.is_empty():
				return done.call("Has picked") if not str(pile.get("chosen", "")).is_empty() else choosing_now.call("Choosing a stone")
	return ["", DeepUi.MUTED, ""]

## What a seat tab says of someone standing at a landing's station ([glyph, words]), and of
## someone done with their respite.
const SEAT_STATIONS: Dictionary = {"rest": ["heart", "At the fire"], "appraise": ["loupe", "At the bench"], "wish": ["drop", "At the well"], "up": ["lift", "Looking at the lift"]}
const SEAT_DONE: Dictionary = {"rest": "Rested by the fire", "appraise": "Appraised a stone", "wish": "Used the well"}

func me() -> Dictionary:
	return DeepDescent.player(run, local_id)

func editable() -> bool:
	return DeepDescent.bench_open(run) and not bool(me().get("downed", false))

func is_drawer_open() -> bool:
	return _open

func height() -> float:
	## How much of the bottom of the screen the dock takes. The party's tabs stand on the dock
	## and take their height above it. The bag is a column at the right (`column_width`) and
	## adds nothing here.
	return _height + (0.0 if DeepUi.phone else 28.0) + _tabs_lift()

# --- choosing one of your own ------------------------------------------------------------------
##
## Nothing in the mine is worked on through a list of names. When a choice wants one of your
## dice or one of your stones, the ask (ask_sheet.gd) stands in the middle of the screen with
## a slot for it, and the things that would do stay lit on the dock while the rest step back;
## the one clicked drops into the slot. Right-click still opens the close look, so a die can
## be read before it is chosen.

func choosing() -> bool:
	return not _offer.is_empty()

func centre_of(kind: String, id: String = "") -> Vector2:
	## The middle of a thing in the dock, on the screen, or Vector2.INF when it is not drawn.
	var spot: Variant = _spots.get("%s:%s" % [kind, id], null)
	if spot == null and kind == "bag" and bag_anchor.is_valid():
		spot = bag_anchor.call()
	if spot == null or not is_instance_valid(spot) or not (spot as Control).is_visible_in_tree():
		return Vector2.INF
	return (spot as Control).get_global_rect().get_center()

func veil(stone_id: String) -> void:
	_veiled[stone_id] = true
	var spot: Variant = _spots.get("stone:" + stone_id, null)
	if spot != null and is_instance_valid(spot):
		(spot as Control).modulate.a = 0.0

func unveil(stone_id: String) -> void:
	## The gem has landed: it shows, kicks, and its ring flashes.
	_veiled.erase(stone_id)
	var spot: Variant = _spots.get("stone:" + stone_id, null)
	if spot == null or not is_instance_valid(spot):
		return
	var control: Control = spot
	control.modulate.a = 1.0
	DeepUi.pulse(control, 1.7, 0.5)
	for child in control.get_children():
		if child.has_method("fire"):
			child.fire()

func flash_sockets(indices: Array, badge: String = "") -> void:
	## Sockets that have just taken a stone: each kicks and its ring flashes, and the first has
	## the stone's weight float up over it. Waits a frame for the dock drawn from the new rail.
	if DeepUi.headless() or not is_inside_tree():
		return
	await get_tree().process_frame
	for at in range(indices.size()):
		var spot: Variant = _spots.get("socket:%d" % int(indices[at]), null)
		if spot == null or not is_instance_valid(spot) or not (spot as Control).is_visible_in_tree():
			continue
		var slot: Control = spot
		DeepUi.pulse(slot, 1.3, 0.45)
		for child in slot.get_children():
			if child.has_method("fire"):
				child.fire()
		if at == 0 and not badge.is_empty():
			var over: Vector2 = slot.get_global_rect().get_center() - get_global_rect().position - Vector2(0, BattleScreen.SOCKET_EDGE * 0.66)
			DeepUi.float_text(self, over, badge, DeepUi.GOOD, 16, 26.0, 1.3)

func preview_hp(cost: int) -> void:
	## Health a click about to be made will cost, hatched red on the ring while it is pointed
	## at (0 clears it). A cost never takes the last point.
	_hp_cost = maxi(0, cost)
	_show_hp_cost()

func _show_hp_cost() -> void:
	if _ring == null or not is_instance_valid(_ring):
		return
	_ring.preview = float(clampi(_hp_cost, 0, maxi(0, _ring_hp.x - 1))) / float(maxi(1, _ring_hp.y))

func light_socket(index: int, on: bool) -> void:
	## A socket something on the screen offers to fill, lit while that offer is pointed at.
	var spot: Variant = _spots.get("socket:%d" % index, null)
	if spot == null or not is_instance_valid(spot):
		return
	for child in (spot as Control).get_children():
		if child.has_method("set_ready"):
			child.set_ready(on)

func offer(kind: String, items: Array, prompt: String, refusals: Dictionary = {}) -> void:
	## `kind` is "die" or "stone"; `items` are the things themselves, in the order they should
	## stand. One of them chosen and confirmed emits `chose` with its id. One whose id
	## `refusals` names stays dim and deaf, saying why, so the bowl reads whole while only some
	## of it will do.
	_offer = {"kind": kind, "items": items, "prompt": prompt, "refusals": refusals}
	if ask == null:
		return
	ask.open({"key": "dock_offer", "title": prompt, "glyph": "die" if kind == "die" else "gem", "tone": DeepUi.ACCENT, "confirm": "Choose it",
		"slots": [{"key": "id", "kind": kind, "label": "", "items": items, "refusals": refusals}]})

func cancel_offer() -> void:
	if _offer.is_empty():
		return
	_offer = {}
	if ask != null and ask.is_open() and str(ask.key()) == "dock_offer":
		ask.close()
	unspotlight()

func _ask_answered(key: String, payload: Dictionary) -> void:
	if key != "dock_offer" or _offer.is_empty() or not payload.has("id"):
		return
	_offer = {}
	unspotlight()
	chose.emit(str(payload.id))

func spotlight(wanted: Dictionary) -> void:
	## Lights the things the ask would take and steps everything else back; opens the bag
	## when something that would do is in it.
	_spot = wanted
	if not _open:
		var haul_ids: Array = me().get("haul", []).map(func(s: Dictionary) -> String: return str(s.get("id", "")))
		if wanted.get("stone", []).any(func(id: Variant) -> bool: return haul_ids.has(str(id))):
			set_drawer(true)
			_ask_opened = true
	_apply_spotlight()

func unspotlight() -> void:
	## Clears the spotlight before shutting the bag: shutting it rebuilds the dock, and a
	## rebuild while the spotlight still stands would start dimming the fresh controls.
	var was_lit: bool = not _spot.is_empty()
	_spot = {}
	if _ask_opened:
		_ask_opened = false
		if _open:
			set_drawer(false)
	if was_lit:
		_apply_spotlight()

func spotlit(kind: String, id: String) -> bool:
	return _spot.get(kind, []).has(id)

func _refused(plate: Control, kind: String, id: String) -> Control:
	## A thing the open ask will not take is dimmed here, and its plate says why in red under
	## the rest: a dimmed d6 read only "d6, 6 faces", and the reason was never shown.
	if ask == null or not ask.is_open():
		return plate
	var why: String = str(ask.refusal(kind, id))
	if not why.is_empty():
		var line := DeepUi.stat(plate, "cross_out", why, DeepUi.BAD, 12)
		var words: Label = line.get_node("Value")
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.custom_minimum_size.x = 240
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return plate

func _apply_spotlight() -> void:
	## One control can stand under two keys (a set gem is both "socket:N" and "stone:<id>"):
	## it is lit when any of its keys is, and dimmed or lit once.
	var lit_of: Dictionary = {}
	var veiled: Dictionary = {}
	for key in _spots:
		var spot: Variant = _spots[key]
		if not (spot is Control and is_instance_valid(spot)):
			continue
		var parts: PackedStringArray = str(key).split(":")
		var kind: String = str(parts[0])
		var id: String = str(parts[1]) if parts.size() > 1 else ""
		var lit: bool = _spot.is_empty() or spotlit(kind, id)
		## The tray holds the dice: it stays lit while any of them is wanted, or its dimming
		## would dim the lit dice with the rest.
		if kind == "dice":
			lit = _spot.is_empty() or not _spot.get("die", []).is_empty()
		if _veiled.has(id):
			veiled[spot] = true
		lit_of[spot] = bool(lit_of.get(spot, false)) or lit
	for spot in lit_of:
		if veiled.has(spot):
			continue
		var control: Control = spot
		var lit: bool = bool(lit_of[spot])
		var goal: Color = Color.WHITE if lit else Color(0.5, 0.5, 0.55, 0.45)
		if DeepUi.headless() or not control.is_inside_tree():
			control.modulate = goal
		elif control.modulate != goal:
			control.create_tween().tween_property(control, "modulate", goal, 0.16).set_trans(Tween.TRANS_SINE)
		for child in control.get_children():
			if child.has_method("set_ready"):
				child.set_ready(not _spot.is_empty() and lit)

func set_drawer(open: bool) -> void:
	if open == _open:
		return
	_open = open
	DeepAudio.play("ui_open" if open else "ui_close", {"volume": 0.6})
	_key = ""
	show_run(run)
	if open and not DeepUi.headless():
		DeepUi.pop_in(_drawer, 0.0, 0.97, 0.18)
	drawer_toggled.emit(open)

func toggle_drawer() -> void:
	## Opened or shut by hand: the player's to keep, whatever an ask or a drag does.
	_ask_opened = false
	_drag_opened = false
	set_drawer(not _open)

func show_run(state: Dictionary) -> void:
	run = state
	## Put away through a fight, which sends a new state with every step it plays: nothing
	## here is drawn then, and the key below catches it up the moment it is shown again.
	if not visible:
		return
	var unit: Dictionary = me()
	_sync_tabs()
	## Rebuilt only when something it shows has changed, so a drag is never pulled out from
	## under the pointer by a state that moved for some other reason.
	## A stone or a die keeps its id when it is worked on — a wheel cuts it again, an oven
	## fires it, a smith hammers it — so what each of them shows goes in the key too, or the
	## dock would go on drawing the one that was there before.
	var ids: Array = []
	for stone in unit.get("rail", []):
		ids.append(DeepUi.stone_marks(stone) if stone is Dictionary else "-")
	for line in unit.get("riders", []):
		ids.append("|")
		for rider in line:
			ids.append(DeepUi.stone_marks(rider))
	for group in ["dice", "haul"]:
		ids.append("|")
		for item in unit.get(group, []):
			ids.append(DeepUi.stone_marks(item))
	## The bag's sort, filters and page are in the key too, as is the column's height: a window
	## made taller holds more tiles a page.
	var key: String = "%s#%s|%s|%s|%s#%s#%s#%d#%d#%d#%s#%s#%d#%d#%d" % [",".join(ids), str(show_appraised), str(show_raw), str(show_geodes), str(StoneBrowser.settings(self, "bag")), str(editable()), str(_open), int(unit.get("hp", 0)), int(unit.get("max_hp", 0)), int(unit.get("ore", 0)),
		str(run.get("players", []).map(func(p: Dictionary) -> String: return str(p.get("id", "")) + str(p.get("connected", true)))), _reading, int(_pages.get("bag_page", 0)), int(size.x), int(size.y)]
	if key == _key:
		return
	_key = key
	_targets = []
	_build_dock(unit)
	_fit_dock()
	_drawer.visible = _open
	if _open:
		_build_drawer(unit)
	_show_pane(unit)
	_dock.visible = true
	if not _spot.is_empty():
		_apply_spotlight()

# --- the dock ----------------------------------------------------------------------------------

func _build_dock(unit: Dictionary) -> void:
	## The fight's dock at rest (docs/UI_REDO.md): the face in its ring of health, the rail
	## with names over the stones and triggers under them, the five dice. No headings: the things say what they are.
	DeepUi.clear(_dock)
	_spots = {}
	## Eight stones on the rail (seven sockets and a Birthstone) only fit the screen with the
	## gaps and the captions drawn in a little; every shorter rail keeps its room.
	var rail: Array = unit.get("rail", [])
	var birth: Dictionary = DeepStone.birthstone_for(unit)
	var tight: bool = rail.size() + (0 if birth.is_empty() else 1) >= 8
	var cap: float = BattleScreen.SOCKET_EDGE + (2.0 if tight else 8.0)
	var columns := DeepUi.hbox(_dock, 6 if tight else int(BattleScreen.DOCK_GAP))
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	## Far left: your face, as the fight's dock has it.
	var ring := VitalsRing.new(BattleScreen.VITALS_EDGE, str(unit.get("character", "")))
	ring.portrait.mood = Roster.resting_mood(unit)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hp: int = int(unit.get("hp", 0))
	var most: int = maxi(1, int(unit.get("max_hp", 1)))
	ring.set_values(float(hp) / float(most), "%s / %s" % [DeepUi.number(hp), DeepUi.number(int(unit.get("max_hp", 0)))])
	columns.add_child(ring)
	_ring = ring
	_ring_hp = Vector2i(hp, most)
	_show_hp_cost()
	Tips.attach(ring, func() -> Control: return Plates.words(str(unit.get("name", "")), "Health %s of %s. The ring fills as you heal and empties as you are hurt; block, in a fight, is an arc outside it." % [DeepUi.number(hp), DeepUi.number(most)], DeepContent.character_title(str(unit.get("character", ""))), DeepUi.HP))
	## Your rail.
	var left := DeepUi.vbox(columns, 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_FILL
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	## No gap over the rail: the names over the rings take the room the line over the dice takes.
	var rail_row := DeepUi.hbox(left, 0 if tight else int(BattleScreen.RAIL_GAP))
	rail_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	rail_row.custom_minimum_size.y = BattleScreen.RING_TOP + BattleScreen.SOCKET_EDGE + 2.0 + BattleScreen.TRIGGER_ROW
	## Where the fight's Resonance meter stands: empty, so the rail stands where it stands
	## in a fight.
	var under := DeepUi.gap(left, BattleScreen.METER_ROW)
	under.size_flags_vertical = Control.SIZE_EXPAND_FILL
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_row.tooltip_text = "Drag a stone from the bag onto a socket to set it, or a set stone back into the bag." if editable() else ""
	for index in range(rail.size()):
		_socket(rail_row, unit, index, cap)
	if not birth.is_empty():
		## Built the way a socket is, name over slot over tiers: in a row that stretches what
		## it holds, a bare picture would take the height of its neighbours' captions as well
		## and hang out of line with every stone beside it.
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		rail_row.add_child(card)
		BattleScreen.name_row(card, str(birth.get("name", "")), GemMesh.tint(birth).lightened(0.35), cap)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(BattleScreen.SOCKET_EDGE, BattleScreen.SOCKET_EDGE)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(holder)
		_spots["birthstone:"] = card
		var bezel := BattleScreen.SocketRing.new("BIRTHSTONE", false)
		bezel.birth_tint = GemMesh.tint(birth)
		bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(bezel)
		var picture := Thumbs.GemThumb.new(birth, BattleScreen.SOCKET_EDGE - 22)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
		## Its tiers under it, as the fight's dock lays them, none lit.
		BattleScreen.lay_tiers(BattleScreen.trigger_row(card), unit.get("birthstone", {}).get("tiers", []), [], false)
		Tips.attach(card, func() -> Control: return _birth_plate(unit, birth), {"tone": GemMesh.tint(birth)})
		_inspectable(card, func() -> void: Inspector.stone(birth))
	var divider := DeepUi.rule(columns, DeepUi.LEDGER_LINE)
	divider.custom_minimum_size = Vector2(3, 0)
	## Your five dice.
	var middle := DeepUi.vbox(columns, 6)
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	## The fight's line over the dice and its buttons under them, as empty rows of the same
	## height, so the dice stand where they stand in a fight.
	DeepUi.gap(middle, BattleScreen.OVER_ROW).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := DeepUi.hbox(middle, 2 if tight else int(BattleScreen.TRAY_GAP))
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.tooltip_text = "Drag a die onto another to change their places." if editable() else ""
	_spots["dice:"] = tray
	var dice: Array = unit.get("dice", [])
	for index in range(dice.size()):
		_die_slot(tray, unit, index)
	DeepUi.gap(middle, BattleScreen.BUTTONS_ROW).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _birth_plate(unit: Dictionary, birth: Dictionary) -> Control:
	## The Birthstone's plate outside a fight: its tiers and their words.
	var box: VBoxContainer = Plates.plate()
	var tint: Color = GemMesh.tint(birth)
	Plates.head(box, str(birth.get("name", "Birthstone")), "your Birthstone", tint.lightened(0.3))
	if not str(birth.get("text", "")).is_empty():
		DeepUi.effect_text(box, str(birth.get("text", "")), 12, DeepUi.MUTED)
	var tiers: Array = unit.get("birthstone", {}).get("tiers", [])
	if not tiers.is_empty():
		Plates.section(box, "Its tiers")
	for tier in tiers:
		var row := DeepUi.hbox(box, 8)
		var tone: Color = DeepUi.BAD if bool(tier.get("penalty", false)) else DeepUi.MUTED
		DiceIcons.build(row, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), 16, tone)
		var said := DeepUi.vbox(row, 0)
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(said, str(tier.get("name", "")), 12, tone)
		DeepUi.effect_text(said, str(tier.get("text", "")), 11, DeepUi.PAPER)
	Plates.footer(box)
	return box

func _socket(parent: Node, unit: Dictionary, index: int, cap: float = -1.0) -> void:
	if cap < 0.0:
		cap = BattleScreen.SOCKET_EDGE + 8.0
	## cap: how wide the name over the stone may run (narrower on an eight-stone rail).
	var sockets: Array = unit.get("sockets", [])
	var color: String = str(sockets[index]) if index < sockets.size() else DeepContent.SOCKET_RAINBOW
	var stone: Variant = unit.rail[index]
	var set_here: bool = stone is Dictionary
	## The riders fan out behind the card: a row of no height before it, so their rings are
	## drawn under the card and take no room in the rail.
	var host := VBoxContainer.new()
	host.add_theme_constant_override("separation", 0)
	host.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(host)
	var fan := Control.new()
	fan.custom_minimum_size = Vector2(cap, 0)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(fan)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(card)
	var riders: Array = DeepStone.riders_of(unit, index)
	## A socket with no gem of its own wears its first rider in front, in the gem's place and
	## named in the Void's blue (as the fight's dock does); the rest fan out behind. An empty
	## ring saying "Any" over faint riders read as a socket where nothing fires.
	var lead: Dictionary = riders[0] if not set_here and not riders.is_empty() else {}
	## Its name over the ring (an empty socket's color in its place), its trigger under it.
	if set_here:
		BattleScreen.name_row(card, DeepUi.skill_name(stone), DeepUi.PAPER, cap)
	elif not lead.is_empty():
		BattleScreen.name_row(card, DeepUi.skill_name(lead), DeepUi.INFO, cap)
	else:
		BattleScreen.name_row(card, DeepContent.socket_name(color), DeepUi.MUTED, cap)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(BattleScreen.SOCKET_EDGE, BattleScreen.SOCKET_EDGE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(slot)
	var ring := BattleScreen.SocketRing.new(color if lead.is_empty() else "VOID", not set_here and lead.is_empty())
	ring.front = not lead.is_empty()
	if set_here:
		ring.shown = 1 if DeepStone.shows(stone, color) else 0
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	_spots["socket:%d" % index] = slot
	var data: Dictionary = {}
	if set_here:
		_spots["stone:" + str(stone.id)] = slot
		card.set_meta("pick", ["stone", str(stone.id)])
		var picture := Thumbs.GemThumb.new(stone, BattleScreen.SOCKET_EDGE - 22)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(picture)
		_lay_trigger(card, stone, _rail_context(unit, index))
		var set_stone: Dictionary = stone
		Tips.attach(card, func() -> Control: return _refused(Plates.gem(set_stone, _rail_context(unit, index), [], {}, [], _rider_opts(unit, index, set_stone)), "stone", str(set_stone.id)), {"tone": DeepUi.color(DeepStone.color(set_stone)), "keep": true})
		if editable() and not DeepStone.is_locked(stone):
			data = {"kind": "stone", "stone_id": str(stone.id), "from_socket": index, "appraised": true}
			card.mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif not lead.is_empty():
		var lead_id: String = str(lead.get("id", ""))
		_spots["stone:" + lead_id] = slot
		card.set_meta("pick", ["stone", lead_id])
		if _veiled.has(lead_id):
			slot.modulate.a = 0.0
		var front := Thumbs.GemThumb.new(lead, BattleScreen.SOCKET_EDGE - 22)
		front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
		front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(front)
		_lay_trigger(card, lead, {})
		Tips.attach(card, func() -> Control: return _refused(Plates.gem(lead, {}, [], {}, [], _rider_opts(unit, index, lead, true)), "stone", lead_id), {"tone": DeepUi.INFO, "keep": true})
		if editable() and not DeepStone.is_locked(lead):
			data = {"kind": "stone", "stone_id": lead_id, "from_socket": index, "rider": 0, "appraised": true}
			card.mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		## The trigger's row left empty, as the gems' cards have it.
		BattleScreen.trigger_row(card)
		Tips.attach(card, func() -> Control: return Plates.words("An empty socket", "Drag any appraised stone onto it. A socket that shows the stone's color lights, and adds a point of Resonance each time the stone fires; any other socket holds it unlit. At home the loadout only sets a stone where it is shown.", DeepContent.socket_name(color)))
	if not riders.is_empty():
		_riders_fan(fan, unit, index, riders, 0 if lead.is_empty() else 1)
	var at: int = index
	var shown: Dictionary = stone if set_here else lead
	_wire(card, data, func() -> Control: return Thumbs.GemThumb.new(shown, 60) if not shown.is_empty() else Control.new(),
		func(incoming: Dictionary) -> bool: return _socket_takes(unit, incoming, at) or (not lead.is_empty() and _rider_takes(unit, incoming, at, 0)),
		func(incoming: Dictionary) -> void:
			if lead.is_empty():
				_socket_drop(incoming, at)
			else:
				_front_drop(unit, incoming, at), ring)
	if not lead.is_empty():
		_inspectable(card, func() -> void: Inspector.stone(lead))
	if set_here:
		## The close look reads the same context as the hover plate (`_rail_context`): the
		## fight's own in a fight, else the rail laid flat (a Fingerprint's words) and how often
		## the stone has fired this run (`run_fires`), which the inspector says.
		_inspectable(card, func() -> void:
			var context: Dictionary = _rail_context(unit, at)
			Inspector.stone(stone, {"context": context} if not context.is_empty() else {}))

func _lay_trigger(card: Control, stone: Dictionary, context: Dictionary) -> void:
	## What a set stone asks of the hand, between it and its name, at the rung it stands on:
	## the row the fight's dock lights while the hand would fire it.
	var described: Dictionary = DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(DeepStone.effective(stone, context).cut_step))
	BattleScreen.lay_trigger(BattleScreen.trigger_row(card), described, DeepUi.PAPER)

func _rail_context(unit: Dictionary, socket: int) -> Dictionary:
	## What the rail hands a set stone where it stands: the fight's own context during a fight,
	## else the rail laid flat the way a fight will lay it.
	var battle: Dictionary = DeepDescent.battle(run)
	var fighter: Dictionary = DeepBattle.player(battle, local_id) if not battle.is_empty() else {}
	var flat: int = DeepStone.flat_index(fighter, socket) if not fighter.is_empty() else -1
	if flat >= 0:
		return DeepBattle.rail_context(battle, fighter, flat)
	var laid: Dictionary = {"rail": unit.get("rail", []).duplicate(), "sockets": unit.get("sockets", []).duplicate(), "riders": unit.get("riders", []).duplicate(), "character": str(unit.get("character", ""))}
	DeepStone.flatten_rail(laid)
	var words: Dictionary = DeepStone.fingerprint_words(laid.rail, DeepStone.flat_index(laid, socket))
	var context: Dictionary = {"fingerprint": words} if not words.is_empty() else {}
	## How often the stone has fired this run (`run_counts`, kept on the run player between
	## fights): what a gem that grows with its firings (Hone, Hardening) has grown to so far,
	## so the plate outside a fight can say so.
	var own: Variant = unit.get("rail", [])[socket] if socket >= 0 and socket < unit.get("rail", []).size() else null
	if own is Dictionary:
		context.run_fires = int(unit.get("run_counts", {}).get(str(own.get("id", "")), 0))
	return context

func _rider_opts(unit: Dictionary, socket: int, stone: Dictionary, rider_of: bool = false) -> Dictionary:
	## What a plate on this socket says about the Void gems riding it.
	var opts: Dictionary = {"socket": socket}
	var riders: Array = DeepStone.riders_of(unit, socket)
	if rider_of:
		opts.rider_of = true
		var own: Variant = unit.rail[socket] if socket < unit.get("rail", []).size() else null
		opts.riders = ([own] if own is Dictionary else []) + riders
	elif not riders.is_empty():
		opts.riders = riders
	return opts

func _riders_fan(fan: Control, unit: Dictionary, socket: int, riders: Array, lead: int = 0) -> void:
	## The Void gems riding a socket, fanned out behind its ring, each firing after the socket's
	## own gem in this order. Three show; a count at the ring's corner says how many there are,
	## and the bench lays them out in full. The first `lead` of them stand in front instead (an
	## empty socket's first rider), so the fan starts after them.
	var shown: int = mini(riders.size() - lead, RIDERS_SHOWN)
	for step in range(shown):
		var at: int = step + lead
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(BattleScreen.SOCKET_EDGE, BattleScreen.SOCKET_EDGE)
		chip.size = Vector2(BattleScreen.SOCKET_EDGE, BattleScreen.SOCKET_EDGE)
		chip.position = Vector2(4.0, BattleScreen.RING_TOP) + Fan.STEP * float(step + 1)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		fan.add_child(chip)
		fan.move_child(chip, 0)
		_rider_chip(chip, unit, socket, at, riders[at])
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", DeepUi.capsule(badge, DeepUi.INFO.darkened(0.6), DeepUi.INFO, 2, 9, 0))
	badge.z_index = 3
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	fan.add_child(badge)
	var count := DeepUi.label(badge, "×%d" % riders.size(), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	count.add_theme_font_override("font", DeepUi.bold_font())
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.resized.connect(func() -> void: badge.position = Vector2(-4.0, BattleScreen.RING_TOP - 2.0).round())
	var listed: Array = riders
	Tips.attach(badge, func() -> Control:
		var box: VBoxContainer = Plates.plate(300.0)
		Plates.head(box, "%s riding socket %d" % [DeepUi.plural(listed.size(), "Void gem"), socket + 1], "fire after its gem, in this order", DeepUi.INFO)
		for rider in listed:
			var row := DeepUi.hbox(box, 8)
			var thumb := Thumbs.GemThumb.new(rider, 24)
			thumb.live_on_hover = false
			row.add_child(thumb)
			var words := DeepUi.vbox(row, 0)
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			DeepUi.label(words, DeepUi.skill_name(rider), 13, DeepUi.PAPER)
			DeepUi.effect_text(words, DeepStone.text(rider), 11, DeepUi.MUTED)
		Plates.footer(box, "Open the bench (B) · every rider")
		return box)

func _rider_chip(chip: Control, unit: Dictionary, socket: int, at: int, stone: Dictionary) -> void:
	## One rider's ring behind the socket: a Void ring a stone can be dropped on (to go into the
	## line ahead of it) and dragged from. Its plate says which gem it is.
	_spots["stone:" + str(stone.id)] = chip
	chip.set_meta("pick", ["stone", str(stone.id)])
	if _veiled.has(str(stone.id)):
		chip.modulate.a = 0.0
	var ring := BattleScreen.SocketRing.new("VOID", false)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chip.add_child(ring)
	## A faint copy of the gem inside the ring, in the Void's blue, so the ring says which.
	var ghost := Thumbs.GemThumb.new(stone, BattleScreen.SOCKET_EDGE - 22)
	ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.live_on_hover = false
	ghost.modulate = BattleScreen.VOID_GHOST
	chip.add_child(ghost)
	var data: Dictionary = {}
	if editable() and not DeepStone.is_locked(stone):
		data = {"kind": "stone", "stone_id": str(stone.id), "from_socket": socket, "rider": at, "appraised": true}
		chip.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var rider: Dictionary = stone
	Tips.attach(chip, func() -> Control: return _refused(Plates.gem(rider, {}, [], {}, [], _rider_opts(unit, socket, rider, true)), "stone", str(rider.id)), {"tone": DeepUi.INFO, "keep": true})
	## Another Void gem dropped on this one goes into the line ahead of it.
	_wire(chip, data, func() -> Control: return Thumbs.GemThumb.new(stone, 60),
		func(incoming: Dictionary) -> bool: return _rider_takes(unit, incoming, socket, at),
		func(incoming: Dictionary) -> void: _send({"kind": "socket", "stone_id": str(incoming.stone_id), "index": socket, "at": at}, "dice_lock"), ring)
	_inspectable(chip, func() -> void: Inspector.stone(stone))

func _rider_takes(unit: Dictionary, incoming: Dictionary, socket: int, at: int) -> bool:
	if not editable() or str(incoming.get("kind", "")) != "stone":
		return false
	var stone: Dictionary = DeepOddities.find_stone(unit, str(incoming.get("stone_id", "")))
	if stone.is_empty() or not DeepStone.is_slotless(stone):
		return false
	var line: Array = DeepStone.riders_of(unit, socket)
	if at < line.size() and str(line[at].get("id", "")) == str(stone.id):
		return false
	return DeepDescent.socket_refusal(unit, stone, socket).is_empty()

func _socket_takes(unit: Dictionary, incoming: Dictionary, index: int) -> bool:
	if not editable():
		return false
	match str(incoming.get("kind", "")):
		"stone":
			## Its own socket is no move: a set stone stays set, a rider stays in its line.
			if int(incoming.get("from_socket", -1)) == index:
				return false
			return DeepDescent.socket_refusal(unit, DeepOddities.find_stone(unit, str(incoming.get("stone_id", ""))), index).is_empty()
		"shop_item":
			if str(incoming.get("item_kind", "")) != "stone" or int(unit.get("ore", 0)) < int(incoming.get("price", 0)):
				return false
			## Bought, it would be in the bag: would it then fit here?
			var probe: Dictionary = unit.duplicate(true)
			probe.haul.append(incoming.get("stone", {}))
			return DeepDescent.socket_refusal(probe, incoming.get("stone", {}), index).is_empty()
	return false

func _socket_drop(incoming: Dictionary, index: int) -> void:
	match str(incoming.get("kind", "")):
		"stone":
			_send({"kind": "socket", "stone_id": str(incoming.stone_id), "index": index}, "dice_lock")
		"shop_item":
			_send({"kind": "buy", "item_id": str(incoming.item_id)}, "buy")
			_send({"kind": "socket", "stone_id": str(incoming.get("stone", {}).get("id", "")), "index": index}, "dice_lock")

func _front_drop(unit: Dictionary, incoming: Dictionary, index: int) -> void:
	## Dropped on the rider standing in an empty socket's place: a Void gem goes into the line
	## ahead of it, as on any rider; any other stone is set in the socket, the riders behind it.
	if str(incoming.get("kind", "")) == "stone" and DeepStone.is_slotless(DeepOddities.find_stone(unit, str(incoming.get("stone_id", "")))):
		_send({"kind": "socket", "stone_id": str(incoming.stone_id), "index": index, "at": 0}, "dice_lock")
	else:
		_socket_drop(incoming, index)

func _die_slot(parent: Node, unit: Dictionary, index: int) -> void:
	var die: Dictionary = unit.dice[index]
	var id: String = str(die.get("id", ""))
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 1)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_DRAG if editable() else Control.CURSOR_ARROW
	var material: String = str(die.get("material", ""))
	var pattern: String = str(die.get("pattern", ""))
	var shown_die: Dictionary = die
	Tips.attach(card, func() -> Control: return _refused(Plates.die(shown_die, {}, {"footer": "Drag · change its place · Right-click · everything" if editable() else Plates.FOOTER}), "die", id), {"tone": DiceIcons.die_palette(shown_die).body})
	parent.add_child(card)
	var thumb := Thumbs.DieThumb.new(die, BattleScreen.DIE_EDGE)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(thumb)
	_spots["die:" + id] = card
	card.set_meta("pick", ["die", id])
	## Only what a die is made of, or the pattern cut into it, is written under it: its
	## numbers are on its own faces and the close look has the rest.
	var under: String = DeepDice.material_name(material)
	if under.is_empty():
		under = DeepDice.pattern_name(pattern)
	var words := DeepUi.label(card, under.to_lower(), 10, DeepUi.ACCENT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	words.custom_minimum_size = Vector2(BattleScreen.DIE_EDGE, BattleScreen.DIE_WORDS - 1.0)
	words.clip_text = true
	## The phone's dice have no words under them (the fight's have none there either): the
	## close look says what one is made of.
	words.visible = not DeepUi.phone
	var at: int = index
	var data: Dictionary = {"kind": "die", "die_id": id, "from_slot": index} if editable() else {}
	_wire(card, data, func() -> Control: return Thumbs.DieThumb.new(die, 60),
		func(incoming: Dictionary) -> bool: return editable() and str(incoming.get("kind", "")) == "die" and str(incoming.get("die_id", "")) != id,
		func(incoming: Dictionary) -> void: _send({"kind": "swap_die", "index": at, "die_id": str(incoming.die_id)}, "die_settle"))
	_inspectable(card, func() -> void: Inspector.die(die))

func _shown_haul(unit: Dictionary) -> Array:
	## The stones the bag shows: by the toggles and the Fits filter, then through the stone
	## browser (its color dots and its sort, the vault's own).
	var out: Array = []
	for stone in unit.get("haul", []):
		if DeepStone.is_geode(stone):
			if not show_geodes:
				continue
		elif bool(stone.get("appraised", false)):
			if not show_appraised:
				continue
		elif not show_raw:
			continue
		out.append(stone)
	return StoneBrowser.sorted(self, out, "bag")

func redraw(_keys: Array) -> bool:
	## The stone browser asks whoever hosts its toolbar to draw a part again; the bag has no
	## parts of its own, so it is drawn whole (`_render`).
	return false

func _render() -> void:
	_key = ""
	show_run(run)

func pages() -> int:
	## How many pages the bag's tiles take, as last built.
	return int(get_meta("bag_pages", 1))

func per_page() -> int:
	## How many tiles a page of the column holds, as last built.
	return int(get_meta("bag_per_page", COLUMN_COLUMNS))

func turn_page(to: int) -> void:
	_pages["bag_page"] = clampi(to, 0, pages() - 1)
	DeepAudio.play("ui_tap", {"volume": 0.6})
	_render()

func _build_drawer(unit: Dictionary) -> void:
	## The column, top to foot: the Appraised, Raw and Geodes toggles with their counts; the
	## stone browser's toolbar (the sort as a drop-down and its direction, then the
	## color dots); the tiles, two across, as many rows as the column's height holds; and at the foot
	## the pager, or a word on reading a stone. More stones than fit are turned a page at a
	## time: the column never scrolls.
	DeepUi.clear(_drawer)
	var column := DeepUi.vbox(_drawer, COLUMN_ROW_GAP)
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	var everything: Array = unit.get("haul", [])
	var haul: Array = _shown_haul(unit)
	## The toggles first (the owner, Nov 6, 2026, round 8), then the sort and the color dots.
	var head := DeepUi.hbox(column, 4)
	head.name = "Toggles"
	var appraised_count: int = everything.filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)) and not DeepStone.is_geode(s)).size()
	var geode_count: int = everything.filter(func(s: Dictionary) -> bool: return DeepStone.is_geode(s)).size()
	var raw_count: int = everything.size() - appraised_count - geode_count
	_toggle(head, "gem", str(appraised_count), show_appraised, DeepUi.ACCENT, func() -> void:
		show_appraised = not show_appraised
		_rebuild()).tooltip_text = "%s, ready to set" % DeepUi.plural(appraised_count, "appraised stone")
	## Lit in paper when on, not muted grey: grey is how a toggle looks when it is off.
	_toggle(head, "pick", str(raw_count), show_raw, DeepUi.PAPER, func() -> void:
		show_raw = not show_raw
		_rebuild()).tooltip_text = "%s, still in the rock" % DeepUi.plural(raw_count, "raw stone")
	_toggle(head, "geode", str(geode_count), show_geodes, Color("c8a8ff"), func() -> void:
		show_geodes = not show_geodes
		_rebuild()).tooltip_text = "%s: only the workshop cracks them" % DeepUi.plural(geode_count, "Geode")
	StoneBrowser.toolbar_narrow(self, column, "bag", {"sorts": BAG_SORTS})
	## The tiles take what is left between the toggles and the foot; how many rows that is
	## decides the page.
	var room := Control.new()
	room.name = "Tiles"
	room.mouse_filter = Control.MOUSE_FILTER_PASS
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(room)
	var foot := DeepUi.hbox(column, 6)
	foot.name = "Foot"
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.custom_minimum_size.y = DeepUi.pt(DeepUi.FINGER_LEAST) if DeepUi.phone else FOOT_ROW
	## On the phone the stone tapped is read on a card pinned at the foot (board run-bag),
	## its room kept whether one is read or not, so the page of stones never shifts.
	if DeepUi.phone:
		var card := PanelContainer.new()
		card.name = "ReadingCard"
		card.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.SLATE_LOW, DeepUi.ACCENT_DIM, 10, int(DeepUi.pt(5)), 2, 0))
		card.custom_minimum_size.y = DeepUi.pt(PHONE_CARD)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		column.add_child(card)
		DeepUi.vbox(card, int(DeepUi.pt(3))).name = "Pane"
	var fixed: float = column.get_combined_minimum_size().y
	var tall: float = _column_height() - fixed
	var least: float = DeepUi.pt(PHONE_TILE.x) if DeepUi.phone else GEM_TILE_LEAST
	var most: float = DeepUi.pt(PHONE_TILE.y) if DeepUi.phone else GEM_TILE
	var across: int = PHONE_COLUMNS if DeepUi.phone else COLUMN_COLUMNS
	if DeepUi.phone:
		## Four a row: as wide as the panel lets them stand, between the two sizes.
		most = minf(most, floor((DeepUi.pt(PHONE_INNER) - float(across - 1) * GEM_TILE_GAP) / float(across)))
	var rows: int = maxi(1, int(floor((tall + GEM_TILE_GAP) / (least + GEM_TILE_GAP))))
	var tile: float = clampf(floor((tall - float(rows - 1) * GEM_TILE_GAP) / float(rows)), least, most)
	set_meta("bag_tile", tile)
	var each: int = rows * across
	var count: int = DeepUi.pages(haul.size(), each)
	var page: int = clampi(int(_pages.get("bag_page", 0)), 0, count - 1)
	_pages["bag_page"] = page
	set_meta("bag_pages", count)
	set_meta("bag_per_page", each)
	room.custom_minimum_size.y = float(rows) * (tile + GEM_TILE_GAP) - GEM_TILE_GAP
	var tiles := GridContainer.new()
	tiles.name = "Grid"
	tiles.columns = PHONE_COLUMNS if DeepUi.phone else COLUMN_COLUMNS
	tiles.add_theme_constant_override("h_separation", int(GEM_TILE_GAP))
	tiles.add_theme_constant_override("v_separation", int(GEM_TILE_GAP))
	tiles.mouse_filter = Control.MOUSE_FILTER_PASS
	tiles.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tiles.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tiles.grow_vertical = Control.GROW_DIRECTION_END
	room.add_child(tiles)
	_tiles = tiles
	if haul.is_empty():
		## Where the first row of stones would stand.
		var why: String = "Nothing to show." if everything.is_empty() else "Nothing in the bag is shown: turn a toggle on."
		var words := DeepUi.wrap(room, why, 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER, COLUMN_INNER)
		words.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		words.custom_minimum_size.y = tile
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for stone in DeepUi.page_of(haul, page, each):
		_stone_tile(tiles, stone, tile)
	if count > 1:
		DeepUi.pager(foot, page, count, turn_page, 12)
	elif not haul.is_empty() and _reading.is_empty() and not DeepUi.phone:
		DeepUi.label(foot, DeepUi.touch_words("Point at a stone to read it"), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## The whole column takes a set stone back, and a stall's goods: dropped anywhere on it,
	## between the tiles or on the toolbar's padding, they land in the bag.
	_wire(_drawer, {}, Callable(),
		func(incoming: Dictionary) -> bool:
			if not editable():
				return false
			if str(incoming.get("kind", "")) == "stone":
				return int(incoming.get("from_socket", -1)) >= 0
			return str(incoming.get("kind", "")) == "shop_item" and int(me().get("ore", 0)) >= int(incoming.get("price", 0)),
		func(incoming: Dictionary) -> void:
			if str(incoming.get("kind", "")) == "shop_item":
				_send({"kind": "buy", "item_id": str(incoming.item_id)}, "buy")
			else:
				_send({"kind": "unsocket", "index": int(incoming.from_socket), "stone_id": str(incoming.get("stone_id", ""))}, "ui_back"))

func _rebuild() -> void:
	DeepAudio.play("ui_toggle", {"volume": 0.6})
	_key = ""
	show_run(run)

func _toggle(parent: Node, glyph: String, words: String, on: bool, tone: Color, flip: Callable) -> Button:
	## A capsule that is lit while it is on.
	var b := DeepUi.icon_button(parent, glyph, words, flip, 11, tone if on else DeepUi.MUTED) if not glyph.is_empty() else DeepUi.button(parent, words, flip, 11)
	var fill: Color = tone.darkened(0.6) if on else DeepUi.SLATE_LOW
	var style := DeepUi.capsule(b, fill, tone if on else DeepUi.LEDGER_LINE, 2, 7, 2)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", Color.WHITE if on else DeepUi.MUTED)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_override("font", DeepUi.bold_font())
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## Drawn 20 tall, it was a hard target on a trackpad: its click reaches 7 above and below
	## and half the 4 px gap to each side (DeepUi.reach), the capsule drawn as before.
	DeepUi.reach(b, Vector2(2, 7))
	return b

# --- the reading plate -------------------------------------------------------------------------

func _show_pane(unit: Dictionary) -> void:
	## The stone last pointed at, read on a plate beside the column (the column is two tiles
	## wide: a reading with its Set, Sell and Look under the tiles would have left room for a
	## row or two of stones). It stands while the bag is open and the stone is still in it.
	if _pane == null:
		return
	if DeepUi.phone:
		_phone_card(unit)
		return
	DeepUi.clear(_pane_box)
	var stone: Dictionary = {}
	for candidate in unit.get("haul", []):
		if str(candidate.get("id", "")) == _reading:
			stone = candidate
	_pane.visible = _open and not stone.is_empty()
	if not _pane.visible:
		return
	_fill_pane(_pane_box, unit)
	_place_pane()
	if is_inside_tree():
		_place_pane.call_deferred()

func _phone_card(unit: Dictionary) -> void:
	## The phone's reading: the card at the bag's foot (board run-bag), never the plate beside it.
	_pane.visible = false
	if not _open or _drawer == null:
		return
	var card: Node = _drawer.find_child("ReadingCard", true, false)
	if card == null:
		return
	var box: Node = card.get_node_or_null("Pane")
	if box == null:
		return
	DeepUi.clear(box)
	var held: bool = unit.get("haul", []).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == _reading)
	if not held:
		var hint := DeepUi.wrap(box, "Tap a stone to read it here. Hold one for its card.", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		return
	_fill_pane(box as VBoxContainer, unit)

func _place_pane() -> void:
	## Beside the column, its top level with the tiles' (or the column's, before they are laid).
	if _pane == null or not _pane.visible or _drawer == null:
		return
	var want: Vector2 = _pane.get_combined_minimum_size()
	_pane.size = want
	var left: float = size.x + _drawer.offset_right - COLUMN_WIDTH - COLUMN_GAP - want.x
	var top: float = _drawer.offset_top
	if _tiles != null and is_instance_valid(_tiles) and _tiles.is_inside_tree() and _tiles.size.y > 0.5:
		top = _tiles.get_global_rect().position.y - get_global_rect().position.y - COLUMN_PAD
	var lowest: float = size.y + _drawer.offset_bottom - want.y
	_pane.position = Vector2(maxf(0.0, left), clampf(top, 0.0, maxf(0.0, lowest))).round()

func _fill_pane(pane: VBoxContainer, unit: Dictionary) -> void:
	var stone: Dictionary = {}
	for candidate in unit.get("haul", []):
		if str(candidate.get("id", "")) == _reading:
			stone = candidate
	if stone.is_empty():
		var empty := DeepUi.vbox(pane, 6)
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		DeepUi.icon(empty, "loupe", 36, DeepUi.DIM).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		DeepUi.wrap(empty, DeepUi.touch_words("Point at a stone to read it here. Right-click anything for its full story."), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER, PANE_WIDTH - 20.0)
		return
	var appraised: bool = bool(stone.get("appraised", false)) and not DeepStone.is_geode(stone)
	var top := DeepUi.hbox(pane, 10)
	var frame := DeepUi.center(top)
	var face: float = DeepUi.pt(30) if DeepUi.phone else 60.0
	frame.custom_minimum_size = Vector2(face + 4.0, face + 4.0)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var picture := Thumbs.GemThumb.new(stone, face)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	var words := DeepUi.vbox(top, 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if DeepStone.is_geode(stone):
		DeepUi.label(words, DeepStone.raw_name(stone), 14, DeepUi.PAPER).add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.label(words, "Sealed · the workshop cracks it", 11, DeepUi.MUTED)
	elif not appraised:
		## A raw stone says only its color and its size: nobody has read it yet.
		DeepUi.label(words, DeepStone.raw_name(stone), 14, DeepUi.PAPER).add_theme_font_override("font", DeepUi.bold_font())
		var facts := DeepUi.hbox(words, 8)
		DeepUi.stat(facts, "carat", DeepStone.size_name(int(stone.get("carat", 1))), DeepUi.MUTED, 11)
		DeepUi.stat(facts, "gem", str(DeepContent.color(DeepStone.color(stone)).get("name", "")), DeepUi.color(DeepStone.color(stone)), 11)
	else:
		var grade: Dictionary = DeepStone.grade(stone)
		DeepUi.label(words, DeepUi.skill_name(stone), 14, DeepUi.tier_color(str(grade.tier))).add_theme_font_override("font", DeepUi.bold_font())
		StoneCard.grade_marks(words, stone, 11)
	var words_wide: float = DeepUi.pt(PHONE_INNER) - DeepUi.pt(12) if DeepUi.phone else PANE_WIDTH - 10.0
	if appraised:
		DeepUi.effect_text(pane, DeepStone.text(stone), 12, DeepUi.PAPER, false, words_wide)
	elif not DeepStone.is_geode(stone):
		DeepUi.wrap(pane, "Raw: a merchant reads it for pyrite, a landing for free.", 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, words_wide)
	else:
		DeepUi.wrap(pane, "Nothing down here can open it. Carry it up.", 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, words_wide)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 6)
	buttons.add_theme_constant_override("v_separation", 6)
	pane.add_child(buttons)
	var id: String = str(stone.get("id", ""))
	if appraised and editable():
		## Set: into the first socket that takes it; every socket that does lights up meanwhile.
		var rail: Array = unit.get("rail", [])
		var into: int = -1
		for index in range(rail.size()):
			if into < 0 and (rail[index] == null or DeepStone.is_slotless(stone)) and DeepDescent.socket_refusal(unit, stone, index).is_empty():
				into = index
		if into >= 0:
			var target: int = into
			var set_button := DeepUi.icon_button(buttons, "gem", "Ride socket %d" % (target + 1) if DeepStone.is_slotless(stone) else "Set in socket %d" % (target + 1), func() -> void:
				_send({"kind": "socket", "stone_id": id, "index": target}, "dice_lock"), 12, DeepUi.GOOD)
			DeepUi.ledger_button(set_button, DeepUi.SLATE_HI, DeepUi.GOOD, 6)
		elif not rail.is_empty() and not DeepStone.is_slotless(stone):
			## No empty socket takes it: most often the rail already holds its skill. It can still
			## take the place of that twin; otherwise say why, rather than offer nothing.
			var swap: int = -1
			for index in range(rail.size()):
				if swap < 0 and rail[index] is Dictionary and str(rail[index].get("skill", "")) == str(stone.get("skill", "")) and DeepDescent.socket_refusal(unit, stone, index).is_empty():
					swap = index
			if swap >= 0:
				var twin: int = swap
				var swap_button := DeepUi.icon_button(buttons, "gem", "Swap for your %s (socket %d)" % [str(DeepStone.skill_of(rail[twin]).get("name", "stone")), twin + 1], func() -> void:
					_send({"kind": "socket", "stone_id": id, "index": twin}, "dice_lock"), 12, DeepUi.GOOD)
				DeepUi.ledger_button(swap_button, DeepUi.SLATE_HI, DeepUi.GOOD, 6)
			else:
				var reason: String = DeepDescent.rail_duplicate(unit, stone)
				if reason.is_empty() and rail.has(null):
					reason = DeepDescent.socket_refusal(unit, stone, rail.find(null))
				if not reason.is_empty():
					DeepUi.wrap(pane, "Can't be set: %s." % reason, 11, DeepUi.BAD, HORIZONTAL_ALIGNMENT_LEFT, PANE_WIDTH - 10.0)
	if DeepDescent.at_stall(run) and not DeepStone.is_geode(stone) and not DeepStone.known_fragile(stone) and not bool(me().get("downed", false)):
		var sell := DeepUi.icon_button(buttons, "scales", "Sell · %d" % DeepStone.sell_value(stone), func() -> void: _send({"kind": "sell", "stone_id": id}, "sell"), 12, DeepUi.ORE)
		DeepUi.ledger_button(sell, DeepUi.SLATE_HI, DeepUi.ORE, 6)
	var look := DeepUi.icon_button(buttons, "loupe", "Look", func() -> void: Inspector.stone(stone), 12, DeepUi.PAPER)
	DeepUi.ledger_button(look, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 6)

func _light_fits(unit: Dictionary, stone: Dictionary, on: bool) -> void:
	## The sockets that would take the stone pointed at light green while it is.
	for target in _targets:
		if not is_instance_valid(target.node) or target.get("ring") == null or not is_instance_valid(target.ring):
			continue
		var takes: bool = on and not stone.is_empty() and bool(target.accepts.call({"kind": "stone", "stone_id": str(stone.get("id", "")), "from_socket": -1, "appraised": bool(stone.get("appraised", false))}))
		target.ring.set_ready(takes)

func _stone_tile(parent: Node, stone: Dictionary, edge: float = GEM_TILE) -> void:
	var appraised: bool = bool(stone.get("appraised", false))
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(edge, edge)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if editable() else Control.CURSOR_ARROW
	parent.add_child(tile)
	var id: String = str(stone.get("id", ""))
	var back := Panel.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tone: Color = DeepUi.tier_color(str(DeepStone.grade(stone).tier)) if appraised else DeepUi.color(DeepStone.color(stone))
	back.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.SLATE_LOW, Color(tone, 0.55) if _reading != id else tone, 8, 0, 2, 0))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(back)
	var picture := Thumbs.GemThumb.new(stone, edge - 12.0)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(picture)
	if not appraised:
		tile.modulate = Color(1, 1, 1, 0.8)
	_spots["stone:" + id] = tile
	tile.set_meta("pick", ["stone", id])
	## A copy of a stone the vault keeps, taken off the rail: marked, so it is never mistaken for
	## a find that will come home.
	if bool(run.get("marks_lent", false)) and DeepDescent.is_lent(run, stone):
		var mark := DeepUi.icon(tile, "chest", 14, DeepUi.MUTED)
		mark.position = Vector2(edge - 18.0, 4)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Pointed at: the reading plate opens on it and the sockets that take it light.
	var unit: Dictionary = me()
	tile.mouse_entered.connect(func() -> void:
		_light_fits(unit, stone, true)
		if _reading != id:
			_reading = id
			_show_pane(me())
			## The foot's word on reading a stone has been taken up on: the key no longer matches,
			## and the next state drawn drops it.
			for foot in _drawer.find_children("Foot", "", true, false):
				for child in foot.get_children():
					if child is Label:
						child.visible = false
			for other in _tiles.get_children():
				var face: Node = other.get_child(0) if other.get_child_count() > 0 else null
				if face is Panel:
					var pick: Array = other.get_meta("pick", ["", ""])
					var its: Color = DeepUi.tier_color(str(DeepStone.grade(DeepOddities.find_stone(me(), str(pick[1]))).tier)) if bool(DeepOddities.find_stone(me(), str(pick[1])).get("appraised", false)) else DeepUi.color(DeepStone.color(DeepOddities.find_stone(me(), str(pick[1]))))
					(face as Panel).add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.SLATE_LOW, its if str(pick[1]) == id else Color(its, 0.55), 8, 0, 2, 0)))
	tile.mouse_exited.connect(func() -> void: _light_fits(unit, stone, false))
	Tips.attach(tile, func() -> Control:
		if appraised and not DeepStone.is_geode(stone):
			return _refused(Plates.gem(stone, {}, [], {}, [], {}), "stone", id)
		if DeepStone.is_geode(stone):
			return Plates.words(DeepStone.raw_name(stone), "Sealed: only the workshop can crack it.", "geode", Color("c8a8ff"))
		return _refused(Plates.words(DeepStone.raw_name(stone), "%s, %s. Appraise it at a stall or a landing before it can be set." % [DeepStone.size_name(int(stone.get("carat", 1))), str(DeepContent.color(DeepStone.color(stone)).get("name", "")).to_lower()], "raw", DeepUi.color(DeepStone.color(stone))), "stone", id), {"tone": tone})
	## A sealed Geode is never dragged: there is nothing to set it in and nothing to sell it to.
	var data: Dictionary = {"kind": "stone", "stone_id": id, "from_socket": - 1, "appraised": appraised} if editable() and not DeepStone.is_geode(stone) else {}
	_wire(tile, data, func() -> Control: return Thumbs.GemThumb.new(stone, 60), Callable(), Callable())
	_inspectable(tile, func() -> void: Inspector.stone(stone))

# --- wiring --------------------------------------------------------------------------------------

func _send(cmd: Dictionary, sound: String) -> void:
	DeepAudio.play(sound, {"volume": 0.8})
	command.emit(cmd)

func _inspectable(control: Control, look: Callable) -> void:
	## Right-click, or a plain click that did not become a drag, for the close look; while the
	## ask lights the thing, a plain click picks it instead.
	control.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]):
			return
		if event.button_index == MOUSE_BUTTON_LEFT and not _spot.is_empty() and control.has_meta("pick"):
			var pick: Array = control.get_meta("pick")
			if spotlit(str(pick[0]), str(pick[1])):
				picked.emit(str(pick[0]), str(pick[1]))
			else:
				DeepAudio.play("ui_deny", {"volume": 0.5})
			control.accept_event()
			return
		## On the phone a tap on a stone in the bag reads it on the card at the bag's foot; the
		## card's Look (or a hold) opens the close look.
		if DeepUi.phone and event.button_index == MOUSE_BUTTON_LEFT and _tiles != null and is_instance_valid(_tiles) and control.get_parent() == _tiles:
			DeepAudio.play("ui_tap", {"volume": 0.6})
			control.mouse_entered.emit()
			control.accept_event()
			return
		look.call()
		control.accept_event())

func _wire(control: Control, data: Dictionary, preview: Callable, accepts: Callable, drop: Callable, ring: Control = null) -> void:
	## Something that can be dragged (when `data` is given) and dropped on (when `accepts` is).
	var drag_func: Callable = Callable()
	if not data.is_empty():
		drag_func = func(_at: Vector2) -> Variant:
			var shown: Control = preview.call()
			shown.modulate = Color(1, 1, 1, 0.85)
			control.set_drag_preview(DeepUi.held(shown))
			DeepAudio.play("die_pick", {"gap": 0.0, "volume": 0.7})
			return data
	var can_func: Callable = Callable()
	var drop_func: Callable = Callable()
	if accepts.is_valid():
		can_func = func(_at: Vector2, incoming: Variant) -> bool: return incoming is Dictionary and bool(accepts.call(incoming))
		drop_func = func(_at: Vector2, incoming: Variant) -> void: drop.call(incoming)
		_targets.append({"node": control, "accepts": accepts, "ring": ring})
	control.set_drag_forwarding(drag_func, can_func, drop_func)

func _notification(what: int) -> void:
	## While something is being dragged, the places it could go are lit and the rest dim; a
	## drag from the room opens the drawer, since that is where bought things go, and shuts it
	## again when it ends, so the stall's goods and price tags are not left under it.
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and str(data.get("kind", "")) == "shop_item" and not _open:
			set_drawer(true)
			_drag_opened = true
		for target in _targets:
			if not is_instance_valid(target.node):
				continue
			var takes: bool = data is Dictionary and bool(target.accepts.call(data))
			target.node.modulate = Color(1.25, 1.2, 1.0) if takes else Color(1, 1, 1, 0.55)
			if target.get("ring") != null and is_instance_valid(target.ring):
				target.ring.set_ready(takes)
	elif what == NOTIFICATION_DRAG_END:
		for target in _targets:
			if is_instance_valid(target.node):
				target.node.modulate = Color.WHITE
			if target.get("ring") != null and is_instance_valid(target.ring):
				target.ring.set_ready(false)
		if _drag_opened:
			_drag_opened = false
			## After the drop has been answered, not in the middle of it.
			if _open:
				set_drawer.call_deferred(false)
