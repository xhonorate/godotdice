extends Control
## What the party carries, always at hand outside a fight: the rail and the five dice along
## the bottom of the screen, where the fight's dock stands when there is a fight, and the bag
## in a drawer that slides up above them (opened from the bag on the strip, or B). It stands
## as tall as the fight's dock and draws its stones and dice as large, so nothing at the bottom
## of the screen jumps when a fight begins or ends; in a party the seat tabs stand on it too,
## each saying whether that player is still choosing, done, down or away.
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

signal command(cmd: Dictionary)
signal drawer_toggled(open: bool)
signal chose(id: String)
## A thing on the dock clicked while the ask lights it: `kind` is "stone" or "die".
signal picked(kind: String, id: String)

## A socket, and a die, as large as the fight's dock draws them (a die there has its number
## under it, which this one has not).
const SLOT := BattleScreen.SOCKET_EDGE
const DIE := BattleScreen.DIE_EDGE
## A Void gem riding a socket, and how many of them show at this size before a count.
const RIDER := 18.0
const RIDERS_SHOWN := 3
## The least the dock stands, before it is told how tall the fight's dock is (`dock_height`).
const DOCK_HEIGHT := 150.0
## A stone in the bag drawer and the gap after it.
const GEM_TILE_STEP := 62.0
## The bag drawer's reading pane, and the least columns of stones beside it.
const PANE_WIDTH := 250.0
const DRAWER_COLUMNS := 6

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
var _drawer: PanelContainer
var _drawer_height: float = 0.0
var _stone_flow: HFlowContainer = null
var _open: bool = false
## What the bag shows (docs/UI_REDO.md): appraised stones and raw ones by default, Geodes
## only when asked; sorted by color, carat or grade; only what fits a socket, when asked.
var show_appraised: bool = true
var show_raw: bool = true
var show_geodes: bool = false
var sort_by: String = "color"
var fits_only: bool = false
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
## Stones drawn but not yet shown: a gem the Hollow made Void is on the rail before the rite
## that put it there has finished, and stays out of sight until it lands.
var _veiled: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer = PanelContainer.new()
	_drawer.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.ACCENT_DIM, 14, 12, 3, 5))
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_drawer.offset_left = 120
	_drawer.offset_right = -120
	_drawer.offset_bottom = - _height - 20
	_drawer.offset_top = - _height - 20 - _drawer_height
	## Anything that outgrows the drawer pushes its top up, never its foot down over the dock.
	_drawer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_drawer.visible = false
	add_child(_drawer)
	_dock = PanelContainer.new()
	_dock.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, DeepUi.LEDGER_LINE, 14, 12, 3, 5))
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.offset_left = 16
	_dock.offset_right = -16
	_dock.offset_bottom = -14
	_dock.offset_top = -14 - _height
	add_child(_dock)
	## The party, along the top of the dock, the way a fight shows it. Alone, nobody.
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 6)
	_tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_bar.visible = false
	add_child(_tab_bar)

func _process(_delta: float) -> void:
	## The tabs stand on the dock: their bottom edge is its top edge.
	if _tab_bar != null and _tab_bar.visible:
		_tab_bar.reset_size()
		_tab_bar.position = Vector2(_dock.position.x + 18.0, _dock.position.y - _tab_bar.size.y)

func _fit_dock() -> void:
	## As tall as the fight's dock, or as its own stones and dice need if that is more.
	if _dock == null:
		return
	_height = maxf(maxf(DOCK_HEIGHT, dock_height), _dock.get_combined_minimum_size().y)
	_dock.offset_top = -14 - _height
	_drawer.offset_bottom = - _height - 20
	_drawer.offset_top = - _height - 20 - _drawer_height

# --- the party's tabs --------------------------------------------------------------------------

func _sync_tabs() -> void:
	## A tab a player, the reader's first: the same tabs a fight stands on its dock, so the
	## party is where it was when a fight ends. Each says what that player is doing here, in
	## place of a line of "waiting for" under the room's name. Alone, none.
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
			tab.picked.connect(_look_at.bind(id))
			tab.inspected.connect(_look_at.bind(id))
			_tab_bar.add_child(tab)
			_tabs[id] = tab
		present[id] = true
		var seat: Color = ShaftMap.SEATS[int(unit.get("seat", index)) % ShaftMap.SEATS.size()]
		tab.update(unit, DeepContent.character_title(str(unit.get("character", ""))), seat, mine, seat_status(unit), 0, EffectChips.for_run(unit), true)
		tab.portrait.mood = Roster.resting_mood(unit)
		if mine:
			_tab_bar.move_child(tab, 0)
	for id in _tabs.keys():
		if not present.has(id):
			if is_instance_valid(_tabs[id]):
				_tabs[id].queue_free()
			_tabs.erase(id)

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
	if not bool(unit.get("connected", true)):
		return ["wifi", DeepUi.DIM, "Away"]
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
					return ["lift", DeepUi.GOOD, "Riding the lift up"]
				"descend":
					return ["descend", DeepUi.ACCENT, "Going on down"]
			return choosing_now.call("Taking a respite" if DeepDescent.needs_respite(run, unit) else "Choosing a way on")
		"hoard":
			var pile: Dictionary = run.get("hoard", {}).get(id, {})
			if not pile.is_empty():
				return done.call("Has picked") if not str(pile.get("chosen", "")).is_empty() else choosing_now.call("Choosing a stone")
	return ["", DeepUi.MUTED, ""]

func me() -> Dictionary:
	return DeepDescent.player(run, local_id)

func editable() -> bool:
	return DeepDescent.bench_open(run) and not bool(me().get("downed", false))

func is_drawer_open() -> bool:
	return _open

func height() -> float:
	## How much of the bottom of the screen the dock and its drawer take.
	## The party's tabs stand on the dock and take their height above it.
	var tabs: float = _tab_bar.get_combined_minimum_size().y if _tab_bar != null and _tab_bar.visible else 0.0
	return _height + 28.0 + maxf(tabs, _drawer_height + 6.0 if _open else 0.0)

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
	_apply_spotlight()

func unspotlight() -> void:
	if _spot.is_empty():
		return
	_spot = {}
	_apply_spotlight()

func spotlit(kind: String, id: String) -> bool:
	return _spot.get(kind, []).has(id)

func _apply_spotlight() -> void:
	for key in _spots:
		var spot: Variant = _spots[key]
		if not (spot is Control and is_instance_valid(spot)):
			continue
		var control: Control = spot
		var parts: PackedStringArray = str(key).split(":")
		var kind: String = str(parts[0])
		var id: String = str(parts[1]) if parts.size() > 1 else ""
		var lit: bool = _spot.is_empty() or spotlit(kind, id)
		if _veiled.has(id):
			continue
		var tile: Control = control if kind != "stone" or not control.get_parent() is Control or control.get_parent() == _dock else control
		tile.modulate = Color.WHITE if lit else Color(0.5, 0.5, 0.55, 0.45)
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
	var key: String = "%s#%s|%s|%s|%s|%s#%s#%s#%d#%d#%d#%s#%s" % [",".join(ids), str(show_appraised), str(show_raw), str(show_geodes), sort_by, str(fits_only), str(editable()), str(_open), int(unit.get("hp", 0)), int(unit.get("max_hp", 0)), int(unit.get("ore", 0)),
		str(run.get("players", []).map(func(p: Dictionary) -> String: return str(p.get("id", "")) + str(p.get("connected", true)))), _reading]
	if key == _key:
		return
	_key = key
	_targets = []
	_build_dock(unit)
	_fit_dock()
	_drawer.visible = _open
	if _open:
		var was: float = _drawer_height
		_build_drawer(unit)
		_fit_drawer(unit)
		## A bag that wraps onto more rows stands taller, and the pages above move out of its way.
		if _drawer_height != was:
			drawer_toggled.emit(_open)
	_dock.visible = true
	if not _spot.is_empty():
		_apply_spotlight()

# --- the dock ----------------------------------------------------------------------------------

func _build_dock(unit: Dictionary) -> void:
	## The fight's dock at rest (docs/UI_REDO.md): the face in its ring of health, the rail
	## with names under the stones, the five dice. No headings: the things say what they are.
	DeepUi.clear(_dock)
	_spots = {}
	var columns := DeepUi.hbox(_dock, 16)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	## Far left: your face, as the fight's dock has it.
	var ring := VitalsRing.new(BattleScreen.VITALS_EDGE, str(unit.get("character", "")))
	ring.portrait.mood = Roster.resting_mood(unit)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hp: int = int(unit.get("hp", 0))
	var most: int = maxi(1, int(unit.get("max_hp", 1)))
	ring.set_values(float(hp) / float(most), "%s / %s" % [DeepUi.number(hp), DeepUi.number(int(unit.get("max_hp", 0)))])
	columns.add_child(ring)
	Tips.attach(ring, func() -> Control: return Plates.words(str(unit.get("name", "")), "Health %s of %s. The ring fills as you heal and empties as you are hurt; block, in a fight, is an arc outside it." % [DeepUi.number(hp), DeepUi.number(most)], DeepContent.character_title(str(unit.get("character", ""))), DeepUi.HP))
	## Your rail.
	var left := DeepUi.vbox(columns, 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_FILL
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	DeepUi.gap(left, BattleScreen.OVER_ROW + 4.0)
	var rail_row := DeepUi.hbox(left, 6)
	rail_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	rail_row.custom_minimum_size.y = SLOT + 20
	## Where the fight's Resonance meter stands: empty, so the rail stands where it stands
	## in a fight.
	var under := DeepUi.gap(left, BattleScreen.METER_ROW)
	under.size_flags_vertical = Control.SIZE_EXPAND_FILL
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_row.tooltip_text = "Drag a stone from the bag onto a socket to set it, or a set stone back into the bag." if editable() else ""
	var rail: Array = unit.get("rail", [])
	for index in range(rail.size()):
		_socket(rail_row, unit, index)
	var birth: Dictionary = DeepStone.birthstone_for(unit)
	if not birth.is_empty():
		## Built the way a socket is, slot over name: in a row that stretches what it holds,
		## a bare picture would take the height of its neighbours' captions as well and hang
		## lower than every stone beside it.
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(SLOT, SLOT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail_row.add_child(card)
		card.add_child(holder)
		_spots["birthstone:"] = card
		var bezel := BattleScreen.SocketRing.new("BIRTHSTONE", false)
		bezel.birth_tint = GemMesh.tint(birth)
		bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(bezel)
		var picture := Thumbs.GemThumb.new(birth, SLOT - 22)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
		DeepUi.fit_label(card, str(birth.get("name", "")), 12, GemMesh.tint(birth).lightened(0.35), SLOT + 8)
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
	var tray := DeepUi.hbox(middle, 8)
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

func _socket(parent: Node, unit: Dictionary, index: int) -> void:
	var sockets: Array = unit.get("sockets", [])
	var color: String = str(sockets[index]) if index < sockets.size() else "ANY"
	var stone: Variant = unit.rail[index]
	var set_here: bool = stone is Dictionary
	## The riders fan out behind the card: a row of no height before it, so their rings are
	## drawn under the card and take no room in the rail.
	var host := VBoxContainer.new()
	host.add_theme_constant_override("separation", 0)
	host.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(host)
	var fan := Control.new()
	fan.custom_minimum_size = Vector2(SLOT + 8, 0)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(fan)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(card)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(slot)
	var ring := BattleScreen.SocketRing.new(color, not set_here)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	_spots["socket:%d" % index] = slot
	var data: Dictionary = {}
	if set_here:
		_spots["stone:" + str(stone.id)] = slot
		card.set_meta("pick", ["stone", str(stone.id)])
		var picture := Thumbs.GemThumb.new(stone, SLOT - 22)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 11)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(picture)
		DeepUi.fit_label(card, DeepUi.skill_name(stone), 12, DeepUi.PAPER, SLOT + 8)
		var set_stone: Dictionary = stone
		Tips.attach(card, func() -> Control: return Plates.gem(set_stone, _rail_context(unit, index), [], {}, [], _rider_opts(unit, index, set_stone)), {"tone": DeepUi.color(DeepStone.color(set_stone)), "keep": true})
		if editable() and not DeepStone.is_locked(stone):
			data = {"kind": "stone", "stone_id": str(stone.id), "from_socket": index, "appraised": true}
			card.mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		DeepUi.label(card, "Any" if color == "ANY" else color.capitalize(), 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER).custom_minimum_size.x = SLOT + 8
		Tips.attach(card, func() -> Control: return Plates.words("An empty socket", "Drag any appraised stone onto it. Its color only matters when the loadout is built at home.", "Any" if color == "ANY" else color.capitalize()))
	var riders: Array = DeepStone.riders_of(unit, index)
	if not riders.is_empty():
		_riders_fan(fan, unit, index, riders)
	var at: int = index
	_wire(card, data, func() -> Control: return Thumbs.GemThumb.new(stone, 60) if set_here else Control.new(),
		func(incoming: Dictionary) -> bool: return _socket_takes(unit, incoming, at),
		func(incoming: Dictionary) -> void: _socket_drop(incoming, at), ring)
	if set_here:
		_inspectable(card, func() -> void:
			var battle: Dictionary = DeepDescent.battle(run)
			var fighter: Dictionary = DeepBattle.player(battle, local_id) if not battle.is_empty() else {}
			var flat: int = DeepStone.flat_index(fighter, at) if not fighter.is_empty() else -1
			if flat >= 0:
				Inspector.stone(stone, {"context": DeepBattle.rail_context(battle, fighter, flat)})
				return
			## Out of a fight the rail is laid flat the way a fight will lay it, so a Fingerprint
			## can say what it will be carrying.
			var laid: Dictionary = {"rail": unit.get("rail", []).duplicate(), "sockets": unit.get("sockets", []).duplicate(), "riders": unit.get("riders", []).duplicate(), "character": str(unit.get("character", ""))}
			DeepStone.flatten_rail(laid)
			var words: Dictionary = DeepStone.fingerprint_words(laid.rail, DeepStone.flat_index(laid, at))
			Inspector.stone(stone, {"context": {"fingerprint": words}} if not words.is_empty() else {}))

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
	return {"fingerprint": words} if not words.is_empty() else {}

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

func _riders_fan(fan: Control, unit: Dictionary, socket: int, riders: Array) -> void:
	## The Void gems riding a socket, fanned out behind its ring, each firing after the socket's
	## own gem in this order. Three show; a count at the ring's corner says how many there are,
	## and the bench lays them out in full.
	var shown: int = mini(riders.size(), RIDERS_SHOWN)
	for at in range(shown):
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(SLOT, SLOT)
		chip.size = Vector2(SLOT, SLOT)
		chip.position = Vector2(4.0, 0.0) + Fan.STEP * float(at + 1)
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
	badge.resized.connect(func() -> void: badge.position = Vector2(-4.0, Fan.STEP.y * float(shown) - 2.0).round())
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
	var ghost := Thumbs.GemThumb.new(stone, SLOT - 22)
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
	Tips.attach(chip, func() -> Control: return Plates.gem(rider, {}, [], {}, [], _rider_opts(unit, socket, rider, true)), {"tone": DeepUi.INFO, "keep": true})
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
	Tips.attach(card, func() -> Control: return Plates.die(shown_die, {}, {"footer": "Drag · change its place · Right-click · everything" if editable() else Plates.FOOTER}), {"tone": DiceIcons.die_palette(shown_die).body})
	parent.add_child(card)
	var thumb := Thumbs.DieThumb.new(die, DIE)
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
	words.custom_minimum_size = Vector2(DIE, BattleScreen.DIE_WORDS - 1.0)
	words.clip_text = true
	var at: int = index
	var data: Dictionary = {"kind": "die", "die_id": id, "from_slot": index} if editable() else {}
	_wire(card, data, func() -> Control: return Thumbs.DieThumb.new(die, 60),
		func(incoming: Dictionary) -> bool: return editable() and str(incoming.get("kind", "")) == "die" and str(incoming.get("die_id", "")) != id,
		func(incoming: Dictionary) -> void: _send({"kind": "swap_die", "index": at, "die_id": str(incoming.die_id)}, "die_settle"))
	_inspectable(card, func() -> void: Inspector.die(die))

func _shown_haul(unit: Dictionary) -> Array:
	## The stones the bag shows: by the toggles, the Fits filter, and the sort.
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
		if fits_only and not _fits_somewhere(unit, stone):
			continue
		out.append(stone)
	var color_order: Array = DeepContent.section("colors").keys()
	var tiers: Array = DeepUi.TIER_colorS.keys()
	match sort_by:
		"carat":
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("carat", 1)) > int(b.get("carat", 1)))
		"grade":
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var ta: int = tiers.find(str(DeepStone.grade(a).tier)) if bool(a.get("appraised", false)) else -1
				var tb: int = tiers.find(str(DeepStone.grade(b).tier)) if bool(b.get("appraised", false)) else -1
				if ta != tb:
					return ta > tb
				return int(a.get("carat", 1)) > int(b.get("carat", 1)))
		_:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var ca: int = color_order.find(DeepStone.color(a))
				var cb: int = color_order.find(DeepStone.color(b))
				if ca != cb:
					return ca < cb
				return int(a.get("carat", 1)) > int(b.get("carat", 1)))
	return out

func _fits_somewhere(unit: Dictionary, stone: Dictionary) -> bool:
	## Whether any socket would take this stone now: an empty one, or any for a Void gem.
	if not bool(stone.get("appraised", false)) or DeepStone.is_geode(stone):
		return false
	var rail: Array = unit.get("rail", [])
	for index in range(rail.size()):
		if (rail[index] == null or DeepStone.is_slotless(stone)) and DeepDescent.socket_refusal(unit, stone, index).is_empty():
			return true
	return false

func _fit_drawer(unit: Dictionary) -> void:
	## The bag is as wide as what is in it and no wider, centred over the dock, with the
	## reading pane beside the stones.
	var wide: float = maxf(640.0, size.x)
	var stones: int = _shown_haul(unit).size()
	var want: float = clampf(PANE_WIDTH + 60.0 + GEM_TILE_STEP * float(clampi(stones, DRAWER_COLUMNS, 12)), wide * 0.4, wide - 240.0)
	## Never narrower than its rows of toggles, or it would spill off to the right of centre.
	want = maxf(want, _drawer.get_combined_minimum_size().x)
	var edge: float = (wide - want) * 0.5
	_drawer.offset_left = edge
	_drawer.offset_right = - edge
	var stone_width: float = want - _drawer.get_theme_stylebox("panel").get_minimum_size().x - PANE_WIDTH - 16.0
	var columns: int = maxi(1, int(floor((stone_width + 6.0) / GEM_TILE_STEP)))
	var rows: int = maxi(1, ceili(float(stones) / float(columns)))
	## Every look keeps room for one row of stones, an empty one too, so the drawer stands
	## the same height whichever toggles are on; one that wraps adds its rows on top.
	_stone_flow.custom_minimum_size.y = float(rows) * GEM_TILE_STEP - 6.0
	_drawer_height = _drawer.get_combined_minimum_size().y
	_drawer.offset_top = - _height - 20 - _drawer_height

# --- the drawer --------------------------------------------------------------------------------

func _build_drawer(unit: Dictionary) -> void:
	DeepUi.clear(_drawer)
	var row := DeepUi.hbox(_drawer, 16)
	## Stones.
	var stones := DeepUi.vbox(row, 6)
	stones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var everything: Array = unit.get("haul", [])
	var haul: Array = _shown_haul(unit)
	var head := DeepUi.hbox(stones, 6)
	DeepUi.icon(head, "bag", 15, DeepUi.ACCENT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var count_label := DeepUi.label(head, str(everything.size()), 13, DeepUi.PAPER)
	count_label.add_theme_font_override("font", DeepUi.bold_font())
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var appraised_count: int = everything.filter(func(s: Dictionary) -> bool: return bool(s.get("appraised", false)) and not DeepStone.is_geode(s)).size()
	var geode_count: int = everything.filter(func(s: Dictionary) -> bool: return DeepStone.is_geode(s)).size()
	var raw_count: int = everything.size() - appraised_count - geode_count
	_toggle(head, "gem", "Appraised %d" % appraised_count, show_appraised, DeepUi.ACCENT, func() -> void:
		show_appraised = not show_appraised
		_rebuild())
	_toggle(head, "pick", "Raw %d" % raw_count, show_raw, DeepUi.MUTED, func() -> void:
		show_raw = not show_raw
		_rebuild())
	_toggle(head, "geode", "Geodes %d" % geode_count, show_geodes, Color("c8a8ff"), func() -> void:
		show_geodes = not show_geodes
		_rebuild())
	DeepUi.spacer(head)
	DeepUi.label(head, "Sort", 11, DeepUi.DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for entry in [["color", "Color"], ["carat", "Carat"], ["grade", "Grade"]]:
		var by: String = str(entry[0])
		_toggle(head, "", str(entry[1]), sort_by == by, DeepUi.INFO, func() -> void:
			sort_by = by
			_rebuild())
	_toggle(head, "check", "Fits", fits_only, DeepUi.GOOD, func() -> void:
		fits_only = not fits_only
		_rebuild())
	var stone_flow := HFlowContainer.new()
	stone_flow.add_theme_constant_override("h_separation", 6)
	stone_flow.add_theme_constant_override("v_separation", 6)
	stone_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stone_flow.mouse_filter = Control.MOUSE_FILTER_PASS
	stones.add_child(stone_flow)
	_stone_flow = stone_flow
	if haul.is_empty():
		## Down the middle of the row a stone would stand in.
		var why: String = "Nothing to show." if everything.is_empty() else ("Nothing in the bag fits a socket now." if fits_only else "Nothing in the bag is shown: turn a toggle on.")
		DeepUi.label(stone_flow, why, 12, DeepUi.DIM).custom_minimum_size.y = GEM_TILE_STEP - 6.0
	for stone in haul:
		_stone_tile(stone_flow, stone)
	## The stone side of the drawer takes a set stone back, and a stall's goods.
	_wire(stones, {}, Callable(),
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
	## The reading pane: the stone last pointed at, and what can be done with it.
	var divider := DeepUi.rule(row, DeepUi.LEDGER_LINE)
	divider.custom_minimum_size = Vector2(3, 0)
	var pane := DeepUi.vbox(row, 6)
	pane.custom_minimum_size.x = PANE_WIDTH
	pane.name = "Pane"
	_fill_pane(pane, unit)

func _rebuild() -> void:
	DeepAudio.play("ui_toggle", {"volume": 0.6})
	_key = ""
	show_run(run)

func _toggle(parent: Node, glyph: String, words: String, on: bool, tone: Color, flip: Callable) -> Button:
	## A capsule that is lit while it is on.
	var b := DeepUi.icon_button(parent, glyph, words, flip, 11, tone if on else DeepUi.MUTED) if not glyph.is_empty() else DeepUi.button(parent, words, flip, 11)
	var fill: Color = tone.darkened(0.6) if on else DeepUi.SLATE_LOW
	var style := DeepUi.capsule(b, fill, tone if on else DeepUi.LEDGER_LINE, 2, 12, 2)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", Color.WHITE if on else DeepUi.MUTED)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_override("font", DeepUi.bold_font())
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

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
		DeepUi.wrap(empty, "Point at a stone to read it here. Right-click anything for its full story.", 12, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER, PANE_WIDTH - 20.0)
		return
	var appraised: bool = bool(stone.get("appraised", false)) and not DeepStone.is_geode(stone)
	var top := DeepUi.hbox(pane, 10)
	var frame := DeepUi.center(top)
	frame.custom_minimum_size = Vector2(64, 64)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var picture := Thumbs.GemThumb.new(stone, 60)
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
	if appraised:
		DeepUi.effect_text(pane, DeepStone.text(stone), 12, DeepUi.PAPER, false, PANE_WIDTH - 10.0)
	elif not DeepStone.is_geode(stone):
		DeepUi.wrap(pane, "Raw: a merchant reads it for pyrite, a landing for free.", 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, PANE_WIDTH - 10.0)
	else:
		DeepUi.wrap(pane, "Nothing down here can open it. Carry it up.", 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, PANE_WIDTH - 10.0)
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
			var set_button := DeepUi.icon_button(buttons, "gem", "Ride socket %d" % (target + 1) if DeepStone.is_slotless(stone) else "Set in %d" % (target + 1), func() -> void:
				_send({"kind": "socket", "stone_id": id, "index": target}, "dice_lock"), 12, DeepUi.GOOD)
			DeepUi.ledger_button(set_button, DeepUi.SLATE_HI, DeepUi.GOOD, 6)
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

func _stone_tile(parent: Node, stone: Dictionary) -> void:
	var appraised: bool = bool(stone.get("appraised", false))
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(56, 56)
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
	var picture := Thumbs.GemThumb.new(stone, 46)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
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
		mark.position = Vector2(40, 3)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Pointed at: the reading pane opens on it and the sockets that take it light.
	var unit: Dictionary = me()
	tile.mouse_entered.connect(func() -> void:
		_light_fits(unit, stone, true)
		if _reading != id:
			_reading = id
			var pane: Node = _drawer.find_child("Pane", true, false)
			if pane != null:
				DeepUi.clear(pane)
				_fill_pane(pane, me())
			for other in _stone_flow.get_children():
				var face: Node = other.get_child(0) if other.get_child_count() > 0 else null
				if face is Panel:
					var pick: Array = other.get_meta("pick", ["", ""])
					var its: Color = DeepUi.tier_color(str(DeepStone.grade(DeepOddities.find_stone(me(), str(pick[1]))).tier)) if bool(DeepOddities.find_stone(me(), str(pick[1])).get("appraised", false)) else DeepUi.color(DeepStone.color(DeepOddities.find_stone(me(), str(pick[1]))))
					(face as Panel).add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.SLATE_LOW, its if str(pick[1]) == id else Color(its, 0.55), 8, 0, 2, 0)))
	tile.mouse_exited.connect(func() -> void: _light_fits(unit, stone, false))
	Tips.attach(tile, func() -> Control:
		if appraised and not DeepStone.is_geode(stone):
			return Plates.gem(stone, {}, [], {}, [], {})
		if DeepStone.is_geode(stone):
			return Plates.words(DeepStone.raw_name(stone), "Sealed: only the workshop can crack it.", "geode", Color("c8a8ff"))
		return Plates.words(DeepStone.raw_name(stone), "%s, %s. Appraise it at a stall or a landing before it can be set." % [DeepStone.size_name(int(stone.get("carat", 1))), str(DeepContent.color(DeepStone.color(stone)).get("name", "")).to_lower()], "raw", DeepUi.color(DeepStone.color(stone))), {"tone": tone})
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
	## drag from the room opens the drawer, since that is where bought things go.
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and str(data.get("kind", "")) == "shop_item" and not _open:
			set_drawer(true)
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
