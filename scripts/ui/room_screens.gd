extends RefCounted
## Every room that is not a fight: the merchant, the workshop, the lapidary, the camp, the
## chance encounters, the wager hall, the crucible, a treasure cache, a lift and a vein.
##
## They share one frame. Across the top, a lit diorama of the place beside what it is and
## what it asks of you, with your purse at the right. Below, the room's offers as cards laid
## side by side, each with its picture first, its price or cost as a tag and its action at
## the foot. Along the bottom, pinned so it never scrolls away: equipment, who the party is
## waiting on, and the way out.
##
## Nothing here decides anything. Every button sends the same command the room always took,
## and the page is rebuilt from the snapshot that comes back.

const Catalog = preload("res://scripts/core/catalog.gd")
const Combat = preload("res://scripts/core/combat.gd")
const EngineScript = preload("res://scripts/core/run_engine.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Forge = preload("res://scripts/ui/sprite_forge.gd")
const GemBadge = preload("res://scripts/ui/gem_badge.gd")
const DiceIcons = preload("res://scripts/ui/dice_icons.gd")
const TremorMeter = preload("res://scripts/ui/tremor_meter.gd")
const RoomScene = preload("res://scripts/ui/room_scene.gd")
const MineView = preload("res://scripts/ui/mine_view.gd")

const FLAVOR := {
	"shop": "A lamp, a folding table and a merchant who does not ask where anything came from.",
	"workshop": "An anvil, a file and a smith who can make a die tell a different story.",
	"lapidary": "A loupe, a wheel and a very steady hand. Stones go in rough and come out known.",
	"rest": "The fire burns low and the rock is warm. For a while, nothing down here is trying to kill you.",
	"crucible": "A fire hot enough to make a stone heavier — if you are willing to feed it.",
	"wager": "Five house dice, a green felt table, and a house that is glad of your ore.",
	"treasure": "Nobody has touched this in years, and now it is yours.",
	"lift": "The cage creaks on its rope. Ride up and everything you carry comes home.",
	"mine": "A seam of rock worth breaking. The party swings in turn until its strength is spent.",
	"ABANDONED_CACHE": "A strongbox wedged under a fallen beam. Something glitters inside, and the beam looks ready to shift.",
	"FIELD_MEDIC": "A tired medic has set up a cot between two tunnels, and has bandages for anyone with ore.",
	"ECHO_SHRINE": "A shrine that hums when a die is set on it. Whatever you leave on it comes back changed.",
	"JEWEL_BROKER": "A broker with a velvet tray. Everything on it is for trade; nothing is for sale.",
	"STILL_POOL": "A black pool so still it swallows sound. The rock around it has stopped shaking."}
const RULES := {
	"shop": ["Paid in ore", "Your own stock", "Sells found gems and spare dice"],
	"workshop": ["One service a visit", "5 ore a service", "Reshaping clears engravings"],
	"lapidary": ["Appraise any number of stones", "One Cut or Clarity upgrade a visit", "Loadout upgrades last this expedition"],
	"rest": ["A third of everyone's HP back", "The fallen stand up", "Free"],
	"crucible": ["The only place Carat moves", "Temper pays in HP", "Fuse pays in a found gem"],
	"wager": ["Stake 4, 8 or 12 ore", "One reroll", "The table pays the pattern"],
	"treasure": ["Unguarded", "Finds fill an open socket"],
	"lift": ["The party votes", "Riding up ends the expedition", "Everything carried comes home"],
	"mine": ["Digs itself", "Ore is shared", "A draft of unappraised stones", "Noisy: stirs the tremors"],
	"event": ["One choice", "Or walk on"]}
const MOODS := {"shop": "glints", "lapidary": "glints", "treasure": "glints", "rest": "embers", "crucible": "embers",
	"wager": "coins", "event": "mist", "lift": "lift", "STILL_POOL": "pool"}
const EVENT_PROPS := {"ABANDONED_CACHE": ["rooms", "treasure"], "FIELD_MEDIC": ["props", "heart"], "ECHO_SHRINE": ["props", "sigil"], "JEWEL_BROKER": ["props", "loupe"]}
const ROCK_TONES := {"Small": Color("8d939f"), "Medium": Color("767b87"), "Large": Color("5c616d"), "Gold": Color("c99a3c"), "Shiny": Color("8fc8e8")}
const VEINS := {
	"coin": {"name": "Coin Vein", "tone": Color("e8b661"), "text": "Short, crumbly rocks that give up ore quickly.", "weights": [4, 4, 2, 2, 0], "tags": ["More ore", "Quick to break", "Gold rocks"]},
	"crystal": {"name": "Crystal Vein", "tone": Color("76b6ff"), "text": "Hard rock that takes longer to break but carries more stones.", "weights": [1, 3, 4, 0, 2], "tags": ["More stones", "Tougher rocks", "Shiny rocks hold better stones"]}}

var ui: Control
## Choices made on the page before the command that uses them: which gem the crucible is
## working, which tray gem the broker is being asked for, which D6 is on the shrine.
var crucible_target := ""
var broker_offer := ""
var shrine_die := ""

func _init(owner: Control) -> void:
	ui = owner

func _hero() -> Dictionary:
	return ui._hero()

func _room() -> Dictionary:
	return ui.snapshot.get("room", {})

func _key() -> String:
	return "room:" + str(_room().get("id", ui.snapshot.get("phase_id", "")))

func _ready_locked() -> bool:
	return bool(_hero().get("ready", false))

# --- the frame -----------------------------------------------------------------------

func build(center: VBoxContainer, phase: String) -> void:
	var kind := str(_room().get("kind", ""))
	if phase == "lift": kind = "lift"
	elif phase in ["mine_vote", "mine_draft"]: kind = "mine"
	var title := str(_room().get("name", kind.capitalize()))
	var flavor_key := kind
	if kind == "event":
		var event_key := str(ui.snapshot.get("event", {}).get("key", ""))
		title = str(Catalog.definitions("events").get(event_key, {}).get("name", "A Chance Encounter"))
		flavor_key = event_key
	var parts: Dictionary = _frame(center, kind, title, flavor_key)
	var body: VBoxContainer = parts.body
	var footer: HBoxContainer = parts.footer
	match phase:
		"lift": _lift(body, footer)
		"mine_vote": _mine_vote(body, footer)
		"mine_draft": _mine_dig(body, footer)
		_:
			match kind:
				"shop": _shop(body, footer)
				"workshop": _workshop(body, footer)
				"lapidary": _lapidary(body, footer)
				"rest": _rest(body, footer)
				"event": _event(body, footer)
				"mine": _mine_dig(body, footer)
				"wager": _wager(body, footer)
				"crucible": _crucible(body, footer)
				"treasure": _treasure(body, footer)
				_: _footer(footer, "Move on")

func _frame(center: VBoxContainer, kind: String, title: String, flavor_key: String) -> Dictionary:
	var accent: Color = ui._room_color(kind)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UiKit.panel_box(Color("1b2233"), Color("0e121c"), Color(accent, 0.55), 14, 10, 1.6, 0.2))
	center.add_child(banner)
	var row: HBoxContainer = ui._hbox(banner, 18)
	var scene := RoomScene.new()
	scene.kind = kind
	scene.accent = accent
	scene.art = Forge.room(kind)
	scene.mood = str(MOODS.get(flavor_key, MOODS.get(kind, "")))
	scene.reduced = bool(ui.settings.reduced_motion)
	if EVENT_PROPS.has(flavor_key):
		var source: Array = EVENT_PROPS[flavor_key]
		scene.prop = Forge.room(source[1]) if source[0] == "rooms" else Forge.prop(source[1])
	scene.custom_minimum_size = Vector2(300, 170)
	row.add_child(scene)
	var words: VBoxContainer = ui._vbox(row, 6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui._label(words, title, 32, UiKit.GOLD)
	ui._label(words, str(FLAVOR.get(flavor_key, FLAVOR.get(kind, ""))), 15, UiKit.PAPER, true)
	var pills := HFlowContainer.new()
	pills.add_theme_constant_override("h_separation", 6)
	pills.add_theme_constant_override("v_separation", 6)
	words.add_child(pills)
	for rule in RULES.get(kind, []):
		UiKit.chip(pills, str(rule).to_upper(), accent.lightened(0.2), 11)
	_purse(row, kind)
	var scroll: ScrollContainer = ui._scroll(center)
	var body: VBoxContainer = ui._vbox(scroll, 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.rule(center, Color("22304a"))
	var footer: HBoxContainer = ui._hbox(center, 12)
	return {"body": body, "footer": footer}

func _purse(row: HBoxContainer, kind: String) -> void:
	var hero := _hero()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_box(Color("141a28"), Color("0c1019"), Color(UiKit.LINE, 0.8), 12, 12, 1.2, 0.1))
	card.custom_minimum_size.x = 230
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)
	var box: VBoxContainer = ui._vbox(card, 6)
	ui._label(box, "YOUR PURSE", 11, UiKit.MUTED)
	var ore_row: HBoxContainer = ui._hbox(box, 8)
	UiKit.icon(ore_row, Forge.prop("gold"), 30).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui._label(ore_row, "%d ORE" % int(hero.get("ore", 0)), 24, UiKit.GOLD)
	var hp := int(hero.get("hp", 0))
	var top := int(hero.get("max_hp", 1))
	UiKit.meter(box, float(hp), float(top), Color("2f9e75") if hp * 2 > top else Color("b8413c"), 16, "HP  %d / %d" % [hp, top])
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 4)
	box.add_child(chips)
	if int(hero.get("loupes", 0)) > 0: UiKit.chip(chips, "%d LOUPE%s" % [int(hero.loupes), "" if int(hero.loupes) == 1 else "S"], UiKit.BLUE)
	if not hero.get("haul", []).is_empty(): UiKit.chip(chips, "%d UNAPPRAISED" % hero.haul.size(), UiKit.VIOLET)
	if kind in ["workshop", "lapidary", "event", "wager", "crucible"]:
		var used: bool = _room().get("services", {}).get(ui.controlled_id, false)
		UiKit.chip(chips, "SERVICE USED" if used else "SERVICE AVAILABLE", UiKit.MUTED if used else UiKit.GREEN)

func _footer(footer: HBoxContainer, done: String, ready_button := true, party := true) -> void:
	var gear: Button = ui._button(footer, "Equipment  [%s]" % ui._binding_name("rd_inspect"), ui._show_inventory)
	gear.tooltip_text = "Sockets, dice and relics."
	if party: ui._party_status(footer)
	ui._spacer(footer)
	if ready_button:
		var onward: Button = ui._ready_button(footer, false)
		onward.text = ("Not yet" if _ready_locked() else done) + "  [%s]" % ui._binding_name("rd_ready")
		onward.custom_minimum_size.x = 240

# --- small parts -----------------------------------------------------------------------

func _section(parent: Node, title: String, tone: Color, note := "") -> void:
	var row: HBoxContainer = ui._hbox(parent, 10)
	ui._label(row, title, 13, tone).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not note.is_empty():
		ui._label(row, note, 13, UiKit.MUTED, true).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _flow(parent: Node, gap := 12) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", gap)
	flow.add_theme_constant_override("v_separation", gap)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(flow)
	return flow

func _card(parent: Node, accent: Color, width := 300.0, lit := false, index := -1) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_box(Color("222c44") if lit else Color("1a2235"), Color("0f1420"), Color(accent, 0.95 if lit else 0.45), 12, 14, 2.2 if lit else 1.4, 0.2))
	card.custom_minimum_size.x = width
	parent.add_child(card)
	if index >= 0:
		ui.reveal.show(card, _key(), 0.06 * index, "pop")
	return ui._vbox(card, 8)

func _push(card: VBoxContainer) -> void:
	## Sends whatever comes next to the foot of the card, so a row of cards lines its buttons up.
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(gap)

func _centred(control: Control) -> Control:
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return control

func _carat_mark(parent: Node, carat: int, size_px: int, tone: Color) -> HBoxContainer:
	## A Carat is written as its mark and its number, never as a letter. The marks are reached
	## through the main screen: preloading the gem panel here loads a second copy of the room
	## scene script, and the page stops recognising its own scene.
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.tooltip_text = "Carat %d. %s" % [carat, ui.GemIcons.hint("carat")]
	parent.add_child(cell)
	ui.GemIcons.glyph(cell, "carat", float(size_px) * 1.2, Color(ui.GemPanel.PROPERTY_TINTS.carat, 0.9), cell.tooltip_text)
	_title(cell, str(carat), size_px, tone)
	return cell

func _title(parent: Node, text: String, size_px: int, tone: Color) -> Label:
	var label: Label = ui._label(parent, text, size_px, tone)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _cost(parent: Node, verb: String, price: int, have: int, action: Callable, unavailable := "") -> Button:
	## A buy button that says what is wrong when it cannot be pressed.
	var short := price - have
	var text := unavailable if not unavailable.is_empty() else ("Need %d more ore" % short if short > 0 else "%s  ·  %d ore" % [verb, price])
	var button: Button = ui._button(parent, text, action, unavailable.is_empty() and short <= 0)
	button.disabled = not unavailable.is_empty() or short > 0 or _ready_locked()
	return button

func _note(parent: Node, text: String, tone: Color) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_box(Color(tone, 0.12), Color(tone, 0.05), Color(tone, 0.5), 10, 12, 1.2, 0.0))
	parent.add_child(card)
	ui._label(card, text, 15, tone, true)

func _faces(parent: Node, die: Dictionary, edge: float, marked := -1) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(flow)
	var faces: Array = die.get("faces", [])
	var tone: Color = DiceIcons.palette(str(die.get("key", die.get("shape", "D6")))).body
	for index in faces.size():
		var face: Variant = faces[index]
		var value: int = int(face.get("value", 0)) if face is Dictionary else int(face)
		flow.add_child(DiceIcons.face(edge, value, UiKit.GOLD if index == marked else tone, str(die.get("shape", "D6")), index == marked))
	return flow

func _pips(parent: Node, label: String, rank: int, tone: Color) -> void:
	var row: HBoxContainer = ui._hbox(parent, 8)
	var name: Label = ui._label(row, label, 11, UiKit.MUTED)
	name.custom_minimum_size.x = 64
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(5 * 18, 12)
	strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(func():
		for pip in 5:
			var box := Rect2(pip * 18.0, 1.0, 14.0, 10.0)
			strip.draw_rect(box, tone if pip < rank else Color(tone, 0.14))
			strip.draw_rect(box, Color(tone, 0.6), false, 1.0))
	row.add_child(strip)
	ui._label(row, "%s" % (Catalog.cut_name(rank) if label == "CUT" else Catalog.clarity_name(rank)), 12, tone)

func _voters(parent: Node, choice: String) -> void:
	## Faces of the heroes who have chosen this, so a party can see a vote forming.
	if not ui._party_choice(): return
	var row: HBoxContainer = ui._hbox(parent, 6)
	for hero in ui.snapshot.get("heroes", []):
		if str(ui.snapshot.get("votes", {}).get(str(hero.get("id", "")), "")) != choice: continue
		UiKit.icon(row, Forge.unit(str(hero.get("key", ""))), 28)
		ui._label(row, str(hero.get("player_name", hero.get("name", "Hero"))), 13, UiKit.GREEN).size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _gem_tile(parent: Node, gem: Dictionary, width := 170.0) -> VBoxContainer:
	var tile := _card(parent, ui._gem_color(gem), width)
	var badge := GemBadge.make(gem, 56)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_child(badge)
	_title(tile, ui._gem_name(gem).capitalize() if ui._sealed(gem) else ui._gem_name(gem), 13, ui._gem_color(gem))
	tile.get_parent().tooltip_text = ui._stone_words(gem) if ui._sealed(gem) else ui._preview_text(gem)
	return tile

# --- the merchant -----------------------------------------------------------------------

func _shop(body: VBoxContainer, footer: HBoxContainer) -> void:
	var hero := _hero()
	var ore := int(hero.get("ore", 0))
	var stock: Dictionary = ui.snapshot.get("shop", {}).get(ui.controlled_id, {})
	_section(body, "ON THE TABLE", UiKit.GOLD, "This stock is yours alone; every hero is shown their own.")
	var flow := _flow(body)
	var index := 0
	for offer in stock.get("gems", []):
		var gem: Dictionary = offer.get("gem", {})
		var sold: bool = offer.get("claimed", false)
		var card := _card(flow, ui._gem_color(gem), 290, false, index)
		index += 1
		ui._gem_card_face(card, gem)
		_push(card)
		if sold:
			card.get_parent().modulate = Color(0.7, 0.7, 0.75, 0.8)
			_centred(UiKit.chip(card, "SOLD TO YOU", UiKit.GREEN, 13))
		else:
			_cost(card, "Buy", int(offer.get("price", 0)), ore, func(): ui._command("BuyGem", {"offer_id": offer.id}))
	for offer in stock.get("dice", []):
		var die: Dictionary = offer.get("die", {})
		var card := _card(flow, UiKit.BLUE, 290, false, index)
		index += 1
		_centred(ui._die_chip(card, "preview:stock:" + str(offer.get("id", die.get("id", ""))), die, 96))
		_title(card, ui._die_name(die), 20, UiKit.BLUE)
		_faces(card, die, 22)
		var full: bool = hero.get("reserve_dice", []).size() >= 5
		ui._label(card, "Joins your reserve dice (%d / 5). Swap it in from your equipment." % hero.get("reserve_dice", []).size(), 12, UiKit.MUTED, true)
		_push(card)
		if offer.get("claimed", false):
			_centred(UiKit.chip(card, "SOLD TO YOU", UiKit.GREEN, 13))
		else:
			_cost(card, "Buy", int(offer.get("price", 0)), ore, func(): ui._command("BuyDie", {"offer_id": offer.id}), "Reserve full" if full else "")
	var loupe: Dictionary = stock.get("loupe", {})
	if not loupe.is_empty():
		var card := _card(flow, Color("63d8d0"), 290, false, index)
		_centred(UiKit.icon(card, Forge.prop("loupe"), 92))
		_title(card, "A jeweller's loupe", 20, Color("63d8d0"))
		ui._label(card, "Appraise one stone from your haul, anywhere outside a fight. An appraised find takes an open socket by itself.", 13, UiKit.PAPER, true)
		var carried: int = hero.get("haul", []).size()
		ui._label(card, "You carry %d unappraised stone%s." % [carried, "" if carried == 1 else "s"], 13, UiKit.VIOLET if carried > 0 else UiKit.MUTED, true)
		_push(card)
		if loupe.get("claimed", false):
			_centred(UiKit.chip(card, "SOLD TO YOU", UiKit.GREEN, 13))
		else:
			_cost(card, "Buy", int(loupe.get("price", 0)), ore, func(): ui._command("BuyLoupe", {}))
	var gems: Array = hero.get("gems", []).filter(func(gem: Dictionary) -> bool: return gem.get("found", false) and not gem.get("loadout", false))
	var dice: Array = hero.get("reserve_dice", [])
	_section(body, "SELL TO THE MERCHANT", UiKit.GOLD, "Half their worth in ore. Your loadout is never for sale.")
	if gems.is_empty() and dice.is_empty():
		ui._label(body, "You have nothing the merchant wants: no found gems and no spare dice.", 14, UiKit.MUTED, true)
	var shelf := _flow(body, 10)
	for gem in gems:
		var tile := _gem_tile(shelf, gem)
		if gem.get("equipped", false): _centred(UiKit.chip(tile, "SOCKETED", UiKit.AMBER, 10))
		_push(tile)
		var sell: Button = ui._button(tile, "Sell  ·  %d ore" % (Catalog.gem_value(gem) / 2), func(): ui._command("SellGem", {"gem_id": gem.id}))
		sell.disabled = _ready_locked()
	for die in dice:
		var tile := _card(shelf, UiKit.BLUE, 170)
		_centred(ui._die_chip(tile, "preview:sell:" + str(die.get("id", "")), die, 56))
		_title(tile, ui._die_name(die), 13, UiKit.BLUE)
		_push(tile)
		var price := int(Catalog.DICE.get(die.get("key", die.get("shape", "D6")), {}).get("price", 6)) / 2
		var sell: Button = ui._button(tile, "Sell  ·  %d ore" % price, func(): ui._command("SellDie", {"die_id": die.id}))
		sell.disabled = _ready_locked()
	_footer(footer, "Leave the merchant")

# --- the workshop -----------------------------------------------------------------------

func _workshop(body: VBoxContainer, footer: HBoxContainer) -> void:
	var hero := _hero()
	var used: bool = _room().get("services", {}).get(ui.controlled_id, false)
	var free := false
	for relic in hero.get("relics", []):
		if relic.get("key") == "TINKERS_BELT" and relic.get("equipped", false) and not hero.get("tinker_used", false): free = true
	var payable: bool = free or int(hero.get("ore", 0)) >= 5
	if used:
		_note(body, "The smith wipes down the anvil. Your die is done for this visit.", UiKit.GREEN)
	elif free:
		_note(body, "Tinker's Belt: your next service here is free.", UiKit.GREEN)
	elif not payable:
		_note(body, "A service costs 5 ore and you carry %d." % int(hero.get("ore", 0)), UiKit.AMBER)
	_section(body, "YOUR DICE", UiKit.BLUE, "Reshape a die to the next size up or down, or engrave one face with a new number.")
	var flow := _flow(body)
	var shapes := ["D4", "D6", "D8", "D10", "D12", "D20"]
	var active: Array = hero.get("dice", [])
	var all_dice: Array = active + hero.get("reserve_dice", [])
	for index in all_dice.size():
		var die: Dictionary = all_dice[index]
		var card := _card(flow, UiKit.BLUE, 250, false, index)
		_centred(UiKit.chip(card, ("ACTIVE  ·  SLOT %d" % (index + 1)) if index < active.size() else "RESERVE", UiKit.BLUE if index < active.size() else UiKit.MUTED, 10))
		_centred(ui._die_chip(card, "preview:bench:" + str(die.id), die, 96))
		_title(card, ui._die_name(die), 18, UiKit.PAPER)
		_faces(card, die, 20)
		if die.get("engraved", false): _centred(UiKit.chip(card, "ENGRAVED", UiKit.GOLD, 10))
		_push(card)
		var row: HBoxContainer = ui._hbox(card, 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var at := shapes.find(str(die.get("shape", "D6")))
		for offset in [-1, 1]:
			var next: int = at + int(offset)
			if next < 0 or next >= shapes.size(): continue
			var reshape: Button = ui._button(row, ("◂ " + shapes[next]) if offset < 0 else (shapes[next] + " ▸"), func(): ui._confirm_shape(die, shapes[next]))
			reshape.disabled = used or not payable or _ready_locked()
			reshape.tooltip_text = "Reshape into a standard %s. Engravings are lost." % shapes[next]
		var carve: Button = ui._button(card, "Engrave a face…", func(): engrave(die))
		carve.disabled = used or not payable or _ready_locked()
	_footer(footer, "Leave the workshop")

func engrave(die: Dictionary, face := -1, value := 0) -> void:
	var box: VBoxContainer = ui._modal("Engrave " + ui._die_name(die))
	ui._label(box, "Pick the face to change, then the number it should show. Every physical face stays equally likely to come up.", 15, UiKit.MUTED, true)
	var faces: Array = die.get("faces", [])
	_section(box, "1  ·  THE FACE", UiKit.GOLD)
	var face_row := _flow(box, 8)
	for index in faces.size():
		var shown: Variant = faces[index]
		var number: int = int(shown.get("value", 0)) if shown is Dictionary else int(shown)
		var pick: Button = ui._button(face_row, str(number), func(): engrave(die, index, value), index == face)
		pick.custom_minimum_size = Vector2(56, 48)
		pick.tooltip_text = "Physical face %d, currently %d." % [index + 1, number]
	_section(box, "2  ·  ITS NEW NUMBER", UiKit.GOLD)
	var value_row := _flow(box, 8)
	for number in range(1, int(str(die.get("shape", "D6")).trim_prefix("D")) + 1):
		var pick: Button = ui._button(value_row, str(number), func(): engrave(die, face, number), number == value)
		pick.custom_minimum_size = Vector2(56, 48)
	if face >= 0 and value > 0:
		var after := die.duplicate(true)
		var carved: Array = after.get("faces", []).duplicate(true)
		if carved[face] is Dictionary: carved[face].value = value
		else: carved[face] = value
		after.faces = carved
		_section(box, "AFTER", UiKit.GREEN)
		_faces(box, after, 30, face)
	var price := "free with Tinker's Belt" if _belt_free() else "5 ore"
	var confirm: Button = ui._button(box, "Engrave  ·  %s" % price, func():
		ui._close_overlay()
		ui._command("ModifyDie", {"die_id": die.id, "service": "face", "face_index": face, "value": value}), true)
	confirm.disabled = face < 0 or value <= 0

func _belt_free() -> bool:
	for relic in _hero().get("relics", []):
		if relic.get("key") == "TINKERS_BELT" and relic.get("equipped", false) and not _hero().get("tinker_used", false): return true
	return false

# --- the lapidary -----------------------------------------------------------------------

func _lapidary(body: VBoxContainer, footer: HBoxContainer) -> void:
	var hero := _hero()
	var ore := int(hero.get("ore", 0))
	var used: bool = _room().get("services", {}).get(ui.controlled_id, false)
	var haul: Array = hero.get("haul", [])
	var price := int(EngineScript.APPRAISE_PRICE)
	_section(body, "APPRAISE  ·  %d ORE A STONE" % price, UiKit.VIOLET, "As many as you can pay for. It does not use up your upgrade.")
	if haul.is_empty():
		ui._label(body, "Your haul is empty: no unappraised stones to look at.", 14, UiKit.MUTED, true)
	var stones := _flow(body)
	for index in haul.size():
		var stone: Dictionary = haul[index]
		var card := _card(stones, ui._gem_color(stone), 240, false, index)
		_centred(ui._gem_portrait(card, stone, 72))
		_title(card, "Unappraised %s stone" % str(Catalog.color_definition(str(stone.get("key", ""))).get("name", "")).to_lower(), 16, ui._gem_color(stone))
		ui._label(card, ui._stone_words(stone), 13, UiKit.MUTED, true)
		_push(card)
		_cost(card, "Appraise", price, ore, func(): ui._command("AppraiseGem", {"gem_id": stone.id, "method": "lapidary"}))
	_section(body, "CUT AND POLISH  ·  ONE UPGRADE A VISIT", Color("63d8d0"), "Cut scales what the dice give. Clarity adds a flat amount and eases triggers.")
	if used:
		_note(body, "The wheel has stopped. Your upgrade for this visit is done.", UiKit.GREEN)
	var gems := _flow(body)
	var gem_list: Array = hero.get("gems", [])
	for index in gem_list.size():
		var gem: Dictionary = gem_list[index]
		var card := _card(gems, ui._gem_color(gem), 320, false, index)
		var head: HBoxContainer = ui._hbox(card, 10)
		ui._gem_portrait(head, gem, 56)
		var words: VBoxContainer = ui._vbox(head, 2)
		ui._label(words, ui._gem_name(gem), 17, ui._gem_color(gem))
		ui._gem_title_row(words, gem, 12, UiKit.PAPER, false)
		_pips(card, "CUT", int(gem.get("cut", 1)), Color("9fd8ff"))
		_pips(card, "CLARITY", int(gem.get("clarity", 1)), Color("d8c2ff"))
		if gem.get("loadout", false):
			ui._label(card, "A loadout gem: an upgrade lasts this expedition.", 11, UiKit.MUTED, true)
		_push(card)
		var row: HBoxContainer = ui._hbox(card, 6)
		for property in ["cut", "clarity"]:
			var rank := int(gem.get(property, 1))
			var cost := 5 * (rank + 1)
			var label := "%s max" % property.capitalize() if rank >= 5 else ("+%s  ·  %d ore" % [property.capitalize(), cost])
			var upgrade: Button = ui._button(row, label, func(): ui._upgrade_preview(gem, property))
			upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			upgrade.disabled = rank >= 5 or used or _ready_locked() or ore < cost
			if ore < cost and rank < 5: upgrade.tooltip_text = "Costs %d ore; you carry %d." % [cost, ore]
	_footer(footer, "Leave the lapidary")

# --- the camp ---------------------------------------------------------------------------

func _rest(body: VBoxContainer, footer: HBoxContainer) -> void:
	_section(body, "AROUND THE FIRE", UiKit.AMBER, "Everyone has recovered a third of their maximum HP.")
	var flow := _flow(body)
	var heroes: Array = ui.snapshot.get("heroes", [])
	for index in heroes.size():
		var hero: Dictionary = heroes[index]
		var card := _card(flow, ui._unit_tint(str(hero.get("key", ""))), 250, str(hero.get("id", "")) == ui.controlled_id, index)
		_centred(UiKit.icon(card, Forge.unit(str(hero.get("key", ""))), 96))
		_title(card, str(hero.get("player_name", hero.get("name", "Hero"))), 18, UiKit.PAPER)
		UiKit.meter(card, float(hero.get("hp", 0)), float(hero.get("max_hp", 1)), Color("2f9e75"), 16, "%d / %d HP" % [int(hero.get("hp", 0)), int(hero.get("max_hp", 1))])
		var gained := int(_room().get("recovery", {}).get(str(hero.get("id", "")), 0))
		if gained > 0:
			var heal := _title(card, "+%d HP" % gained, 26, UiKit.GREEN)
			ui.reveal.count(heal, _key(), 0.3 + 0.1 * index, gained, "+%d HP")
		else:
			_title(card, "Already at full strength", 14, UiKit.MUTED)
	var tip := _card(flow, UiKit.AMBER, 300)
	_centred(UiKit.icon(tip, Forge.prop("sigil"), 64))
	_title(tip, "A quiet moment", 18, UiKit.AMBER)
	ui._label(tip, "The best time to rearrange sockets, swap dice and try on relics — nothing is waiting to hit you.", 13, UiKit.PAPER, true)
	_push(tip)
	ui._button(tip, "Open equipment", ui._show_inventory, true)
	_footer(footer, "Break camp")

# --- chance encounters ------------------------------------------------------------------

func _event(body: VBoxContainer, footer: HBoxContainer) -> void:
	var hero := _hero()
	var event: Dictionary = ui.snapshot.get("event", {})
	var key := str(event.get("key", "ABANDONED_CACHE"))
	var used: bool = _room().get("services", {}).get(ui.controlled_id, false)
	if used:
		_note(body, "Your choice is made. Rearrange your equipment if you like, then walk on.", UiKit.GREEN)
		_footer(footer, "Walk on")
		return
	var offers: Array = event.get("offers", {}).get(ui.controlled_id, [])
	var ore_offer := int({"ABANDONED_CACHE": 6, "FIELD_MEDIC": 4, "ECHO_SHRINE": 5, "JEWEL_BROKER": 4, "STILL_POOL": 4}.get(key, 4))
	_section(body, "CHOOSE ONE", Color("d0b0ff"))
	var flow := _flow(body)
	var take := _card(flow, UiKit.GOLD, 250, false, 0)
	_centred(UiKit.icon(take, Forge.prop("gold"), 72))
	_title(take, "+%d ORE" % ore_offer, 30, UiKit.GOLD)
	_title(take, "Take what is offered and move on.", 13, UiKit.MUTED)
	_push(take)
	ui._button(take, "Take the ore", func(): ui._command("EventChoice", {"option": "a"}), true).disabled = _ready_locked()
	match key:
		"ABANDONED_CACHE":
			var card := _card(flow, UiKit.RED, 330, false, 1)
			_title(card, "Pry it open", 20, UiKit.RED)
			if not offers.is_empty():
				ui._gem_card_face(card, offers[0])
			var tags: HBoxContainer = ui._hbox(card, 6)
			tags.alignment = BoxContainer.ALIGNMENT_CENTER
			UiKit.chip(tags, "COSTS 8 HP", UiKit.RED, 12)
			UiKit.chip(tags, "+2 CARAT ALREADY IN IT", UiKit.GREEN, 12)
			_push(card)
			var hp := int(hero.get("hp", 0))
			var pry: Button = ui._button(card, "Pry it open  ·  8 HP" if hp > 8 else "Too hurt to risk it", func(): ui._command("EventChoice", {"option": "b"}), hp > 8)
			pry.disabled = hp <= 8 or _ready_locked()
			pry.tooltip_text = "You have %d HP and would be left with %d." % [hp, hp - 8]
		"FIELD_MEDIC":
			var card := _card(flow, UiKit.GREEN, 300, false, 1)
			_centred(UiKit.icon(card, Forge.prop("heart"), 72))
			var amount := int(ceil(float(hero.get("max_hp", 0)) * 0.2))
			_title(card, "+%d HP" % amount, 30, UiKit.GREEN)
			var after := mini(int(hero.get("max_hp", 1)), int(hero.get("hp", 0)) + amount)
			UiKit.meter(card, float(after), float(hero.get("max_hp", 1)), Color("2f9e75"), 16, "%d → %d HP" % [int(hero.get("hp", 0)), after])
			_centred(UiKit.chip(card, "COSTS 8 ORE", UiKit.GOLD, 12))
			_push(card)
			_cost(card, "Pay the medic", 8, int(hero.get("ore", 0)), func(): ui._command("EventChoice", {"option": "b"}))
		"STILL_POOL":
			var card := _card(flow, UiKit.BLUE, 330, false, 1)
			_title(card, "Sit by the water", 20, UiKit.BLUE)
			var tremor := int(ui.snapshot.get("tremor", 0))
			var calmed := maxi(0, tremor - int(EngineScript.STILL_POOL_CALM))
			var meter := TremorMeter.new()
			meter.reduced_motion = bool(ui.settings.reduced_motion)
			meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.add_child(meter)
			meter.set_tremor(tremor, "The boss")
			_title(card, "Tremors %d%%  →  %d%%" % [roundi(tremor / 10.0), roundi(calmed / 10.0)], 18, UiKit.PAPER)
			ui._label(card, "The whole party's meter settles. The water only calms once.", 13, UiKit.MUTED, true)
			_push(card)
			var sit: Button = ui._button(card, "The water is already still" if event.get("calmed", false) else "Sit a while", func(): ui._command("EventChoice", {"option": "b"}), true)
			sit.disabled = event.get("calmed", false) or _ready_locked()
		"ECHO_SHRINE":
			var card := _card(flow, UiKit.VIOLET, 560, false, 1)
			_title(card, "Leave a D6 on the shrine", 20, UiKit.VIOLET)
			ui._label(card, "1  ·  Choose a D6. Any engraving on it is lost.", 13, UiKit.GOLD)
			var dice_row := _flow(card, 8)
			for die in hero.get("dice", []) + hero.get("reserve_dice", []):
				if str(die.get("shape", "")) != "D6": continue
				var chosen := shrine_die == str(die.id)
				var pick := _card(dice_row, UiKit.GOLD if chosen else UiKit.LINE, 110, chosen)
				_centred(ui._die_chip(pick, "preview:shrine:" + str(die.id), die, 56))
				ui._button(pick, "Chosen" if chosen else "Choose", func(): shrine_die = str(die.id); ui._queue_render(), chosen)
			ui._label(card, "2  ·  Choose what it comes back as.", 13, UiKit.GOLD)
			var variants := _flow(card, 8)
			for variant in ["PAIRED_D6", "ODD_D6", "EVEN_D6"]:
				var form := _card(variants, UiKit.VIOLET, 160)
				_title(form, variant.trim_suffix("_D6").capitalize(), 15, UiKit.PAPER)
				_faces(form, {"shape": "D6", "key": variant, "faces": Catalog.DICE.get(variant, {}).get("faces", [])}, 20)
				_push(form)
				var reforge: Button = ui._button(form, "Reforge", func(): ui._command("EventChoice", {"option": "b", "die_id": shrine_die, "variant": variant}))
				reforge.disabled = shrine_die.is_empty() or _ready_locked()
		"JEWEL_BROKER":
			var card := _card(flow, UiKit.VIOLET, 300, false, 1)
			_centred(UiKit.icon(card, Forge.prop("loupe"), 72))
			_title(card, "Trade with the broker", 20, UiKit.VIOLET)
			ui._label(card, "Pick a gem from the tray below, then the find you give for it — appraised or not. Loadout gems are not for trade.", 13, UiKit.PAPER, true)
	var leave := _card(flow, UiKit.MUTED, 220, false, 2)
	_centred(UiKit.icon(leave, Forge.prop("sigil"), 64))
	_title(leave, "Walk on", 20, UiKit.PAPER)
	_title(leave, "Leave it all where it is.", 13, UiKit.MUTED)
	_push(leave)
	ui._button(leave, "Walk on", func(): ui._command("EventChoice", {"option": "leave"})).disabled = _ready_locked()
	if key == "JEWEL_BROKER":
		_broker(body, offers)
	_footer(footer, "Walk on", false)

func _broker(body: VBoxContainer, offers: Array) -> void:
	var hero := _hero()
	_section(body, "THE BROKER'S TRAY  ·  CHOOSE ONE", UiKit.VIOLET)
	var tray := _flow(body)
	for index in offers.size():
		var offer: Dictionary = offers[index]
		var gem: Dictionary = offer.get("gem", offer)
		var offer_id := str(offer.get("id", gem.get("id", "")))
		var chosen := broker_offer == offer_id
		var card := _card(tray, ui._gem_color(gem), 280, chosen, index + 3)
		ui._gem_card_face(card, gem)
		_push(card)
		ui._button(card, "Chosen  ✓" if chosen else "I want this one", func(): broker_offer = offer_id; ui._queue_render(), chosen)
	var tradable: Array = (hero.get("gems", []) + hero.get("haul", [])).filter(func(item: Dictionary) -> bool: return item.get("found", false) and not item.get("loadout", false) and not item.get("equipped", false))
	_section(body, "WHAT YOU GIVE", UiKit.GOLD, "" if not broker_offer.is_empty() else "Choose a gem from the tray first.")
	if tradable.is_empty():
		ui._label(body, "You hold no unsocketed find the broker would take.", 14, UiKit.MUTED, true)
	var shelf := _flow(body, 10)
	for item in tradable:
		var tile := _gem_tile(shelf, item)
		_push(tile)
		var trade: Button = ui._button(tile, "Give this", func(): ui._command("EventChoice", {"option": "b", "gem_id": item.id, "offer_id": broker_offer}), true)
		trade.disabled = broker_offer.is_empty() or _ready_locked()

# --- the wager hall ---------------------------------------------------------------------

func _wager(body: VBoxContainer, footer: HBoxContainer) -> void:
	var hero := _hero()
	var seat: Dictionary = _room().get("wager", {}).get(ui.controlled_id, {})
	var stake := int(seat.get("stake", 0))
	var hand: Array = seat.get("hand", [])
	var settled: bool = seat.get("settled", false)
	var split: HBoxContainer = ui._hbox(body, 14)
	var felt := PanelContainer.new()
	felt.add_theme_stylebox_override("panel", UiKit.panel_box(Color("235a40"), Color("103322"), Color("c9a24a"), 18, 22, 3.0, 0.1))
	felt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	felt.custom_minimum_size.y = 360
	split.add_child(felt)
	var table: VBoxContainer = ui._vbox(felt, 14)
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	var showing := ""
	if settled:
		var won := int(seat.get("payout", 0))
		var entry: Dictionary = EngineScript.wager_entry(str(seat.get("pattern", "nothing")))
		showing = str(seat.get("pattern", ""))
		var key := "wager-settled:" + str(_room().get("id", ""))
		var name := _title(table, str(entry.get("name", "No pattern")).to_upper(), 34, UiKit.GOLD if won > stake else Color("d9e6dd"))
		ui.reveal.show(name, key, 0.0, "stamp")
		ui.reveal.cue(key, 0.0, ui._sound("coins" if won > stake else "thud"))
		var delta := _title(table, ("+%d ORE" if won >= stake else "−%d ORE") % absi(won - stake), 26, UiKit.GREEN if won > stake else (UiKit.PAPER if won == stake else UiKit.RED))
		ui.reveal.show(delta, key, 0.25, "pop")
		_title(table, "Staked %d  ·  the table paid %d" % [stake, won], 14, Color("cfe3d6"))
		_hand(table, seat.get("dice", []), hand, false)
		_title(table, "The table takes one hand a visit.", 13, Color("9fc2ad"))
	elif stake <= 0:
		_title(table, "PLACE YOUR STAKE", 22, Color("f1e3b8"))
		var chips: HBoxContainer = ui._hbox(table, 22)
		chips.alignment = BoxContainer.ALIGNMENT_CENTER
		var tones := [Color("3f7fd6"), Color("c8463d"), Color("2b2b2b")]
		for index in EngineScript.WAGER_STAKES.size():
			var value := int(EngineScript.WAGER_STAKES[index])
			_chip_button(chips, value, tones[index], int(hero.get("ore", 0)))
		_title(table, "Five of a kind pays ten times your stake. A pair pays nothing.", 14, Color("cfe3d6"))
		var past: Button = ui._button(table, "Walk past the tables", func(): ui._command("SetReady", {"ready": true}))
		_centred(past)
		past.disabled = _ready_locked()
	else:
		var values: Array = []
		for roll in hand: values.append(int(roll.get("value", 0)))
		showing = str(EngineScript.wager_pattern(values))
		var entry: Dictionary = EngineScript.wager_entry(showing)
		var payout := stake * int(entry.get("multiplier", 0))
		_centred(UiKit.chip(table, "STAKED %d ORE" % stake, UiKit.GOLD, 13))
		_hand(table, seat.get("dice", []), hand, not seat.get("rerolled", false))
		_title(table, "Showing %s  ·  pays %d ore" % [str(entry.get("name", "")).to_lower(), payout], 22, UiKit.GOLD if payout > stake else Color("e6efe9"))
		var actions: HBoxContainer = ui._hbox(table, 12)
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		if not seat.get("rerolled", false):
			var reroll: Button = ui._button(actions, "Reroll %d marked  [%s]" % [ui.selected_dice.size(), ui._binding_name("rd_reroll")], func():
				ui._play_sound(ui.dice_sound)
				ui._command("WagerReroll", {"die_ids": ui.selected_dice.duplicate()})
				ui.selected_dice.clear())
			reroll.disabled = ui.selected_dice.is_empty() or _ready_locked()
			reroll.tooltip_text = "Click dice, or press 1–5, to mark them for your one reroll."
		else:
			ui._label(actions, "Your reroll is spent.", 14, Color("cfe3d6")).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ui._button(actions, "Settle  ·  take %d ore" % payout, func(): ui.selected_dice.clear(); ui._command("SettleWager", {}), true).disabled = _ready_locked()
	_paytable(split, showing, stake)
	_footer(footer, "Leave the tables")

func _chip_button(parent: Node, value: int, tone: Color, ore: int) -> void:
	var chip := Button.new()
	chip.text = "%d\nORE" % value
	chip.custom_minimum_size = Vector2(104, 104)
	chip.add_theme_font_size_override("font_size", 22)
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(52)
		style.bg_color = tone.lightened(0.15 if state == "hover" else 0.0) if state != "disabled" else Color(tone, 0.3)
		style.border_color = Color("f1e3b8") if state != "disabled" else Color(1, 1, 1, 0.2)
		style.set_border_width_all(6)
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 6 if state != "pressed" else 2
		chip.add_theme_stylebox_override(state, style)
	chip.add_theme_color_override("font_color", Color("fff8e6"))
	chip.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	chip.disabled = ore < value or _ready_locked()
	chip.tooltip_text = "You need %d more ore." % (value - ore) if ore < value else "Stake %d ore. Pays up to %d on five of a kind." % [value, value * int(EngineScript.WAGER_TABLE[0].multiplier)]
	chip.pressed.connect(func(): ui._play_sound(ui.dice_sound); ui.selected_dice.clear(); ui._command("PlaceWager", {"stake": value}))
	parent.add_child(chip)

func _hand(parent: Node, dice: Array, hand: Array, selectable: bool) -> void:
	var row: HBoxContainer = ui._hbox(parent, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in hand.size():
		var roll: Dictionary = hand[index]
		var die: Dictionary = {}
		for dealt in dice:
			if str(dealt.get("id", "")) == str(roll.get("die_id", "")): die = dealt
		if die.is_empty(): continue
		var id := str(die.id)
		var marked: bool = selectable and ui.selected_dice.has(id)
		var slot: VBoxContainer = ui._vbox(row, 4)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var stack := Control.new()
		stack.custom_minimum_size = Vector2(92, 92)
		slot.add_child(stack)
		var view: Control = ui._die_view("wager:" + id)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(view)
		view.configure(die, roll, marked, false, UiKit.GOLD if marked else UiKit.BLUE)
		if selectable:
			var button := Button.new()
			button.flat = true
			button.toggle_mode = true
			button.button_pressed = marked
			button.disabled = _ready_locked()
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.set_meta("focus_tag", "wager_" + str(index))
			button.pressed.connect(func(): ui._play_sound(ui.click_sound); ui._toggle_die(id))
			button.tooltip_text = "Rolled %d. Click to mark it for the reroll." % int(roll.get("value", 0))
			stack.add_child(button)
		var caption: Label = ui._label(slot, "REROLL" if marked else ("%d" % (index + 1)), 11, UiKit.GOLD if marked else Color("9fc2ad"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _paytable(parent: Node, showing: String, stake: int) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_box(Color("1a2235"), Color("0f1420"), Color("c9a24a", 0.6), 12, 14, 1.4, 0.2))
	card.custom_minimum_size.x = 290
	parent.add_child(card)
	var box: VBoxContainer = ui._vbox(card, 4)
	ui._label(box, "THE TABLE PAYS", 12, UiKit.GOLD)
	for entry in EngineScript.WAGER_TABLE:
		var here: bool = str(entry.key) == showing
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", UiKit.flat(Color(UiKit.GOLD, 0.2) if here else Color(0, 0, 0, 0), Color(UiKit.GOLD, 0.7) if here else Color(0, 0, 0, 0), 6, 6, 1))
		box.add_child(line)
		var row: HBoxContainer = ui._hbox(line, 8)
		var paying := int(entry.multiplier) > 1
		ui._label(row, str(entry.name), 14, UiKit.PAPER if here or paying else UiKit.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mult := "%d×" % int(entry.multiplier)
		if stake > 0: mult += "  ·  %d" % (stake * int(entry.multiplier))
		ui._label(row, mult, 14, UiKit.GOLD if int(entry.multiplier) >= 1 else UiKit.MUTED)
	ui._label(box, "Payouts include your stake: 1× gives it back, 0× keeps it.", 12, UiKit.MUTED, true)

# --- the crucible -----------------------------------------------------------------------

func _crucible(body: VBoxContainer, footer: HBoxContainer) -> void:
	var hero := _hero()
	var used: bool = _room().get("services", {}).get(ui.controlled_id, false)
	if used:
		_note(body, "The fire is spent. Your offering for this visit is made.", UiKit.GREEN)
		_footer(footer, "Leave the crucible")
		return
	var gems: Array = hero.get("gems", [])
	var target: Dictionary = {}
	for gem in gems:
		if str(gem.get("id", "")) == crucible_target: target = gem
	if target.is_empty():
		for gem in gems:
			if int(gem.get("carat", 1)) < 24:
				target = gem
				break
		crucible_target = str(target.get("id", ""))
	var split: HBoxContainer = ui._hbox(body, 14)
	var picker := _card(split, UiKit.LINE, 360)
	picker.get_parent().size_flags_vertical = Control.SIZE_FILL
	ui._label(picker, "CHOOSE A GEM FOR THE FIRE", 12, UiKit.GOLD)
	var tiles := _flow(picker, 8)
	for gem in gems:
		var chosen := str(gem.get("id", "")) == crucible_target
		var tile := _card(tiles, ui._gem_color(gem), 100, chosen)
		tile.add_child(_centred(GemBadge.make(gem, 44)))
		_carat_mark(tile, int(gem.get("carat", 1)), 12, UiKit.GOLD if chosen else UiKit.MUTED)
		var holder: Control = tile.get_parent()
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		holder.tooltip_text = "%s\nCarat %d" % [ui._gem_name(gem), int(gem.get("carat", 1))]
		holder.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				crucible_target = str(gem.get("id", ""))
				ui._play_sound(ui.click_sound)
				ui._queue_render())
	var forge: VBoxContainer = ui._vbox(split, 12)
	forge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if target.is_empty():
		_note(forge, "Every gem you carry is already at the highest Carat.", UiKit.MUTED)
		_footer(footer, "Leave the crucible")
		return
	var carat := int(target.get("carat", 1))
	var gain := int(EngineScript.CRUCIBLE_CARAT_GAIN)
	var head := _card(forge, Color("ff8fa3"), 0, true)
	var head_row: HBoxContainer = ui._hbox(head, 16)
	ui._gem_portrait(head_row, target, 120)
	var words: VBoxContainer = ui._vbox(head_row, 6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._label(words, ui._gem_name(target), 24, ui._gem_color(target))
	ui._gem_title_row(words, target, 13, UiKit.PAPER, false)
	var climb: HBoxContainer = ui._hbox(words, 10)
	ui._label(climb, "CARAT", 12, UiKit.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.meter(climb, float(carat), 24.0, UiKit.GOLD, 16, "%d / 24" % carat)
	ui._label(words, "Carat multiplies everything it does: ×%.3f now." % Combat.carat_multiplier(carat), 13, UiKit.MUTED, true)
	if carat >= 24:
		_note(forge, "Already at the highest Carat.", UiKit.MUTED)
		_footer(footer, "Leave the crucible")
		return
	var options := _flow(forge)
	var cost := 4 + int(floor(float(carat) / 2.0))
	var temper := _card(options, UiKit.RED, 280)
	_centred(UiKit.icon(temper, Forge.prop("heart"), 56))
	_title(temper, "TEMPER", 20, UiKit.RED)
	_title(temper, "Carat %d → %d" % [carat, mini(24, carat + gain)], 18, UiKit.GREEN)
	_title(temper, "×%.3f → ×%.3f" % [Combat.carat_multiplier(carat), Combat.carat_multiplier(mini(24, carat + gain))], 13, UiKit.PAPER)
	var hp := int(hero.get("hp", 0))
	_centred(UiKit.chip(temper, "COSTS %d HP  ·  LEAVES YOU AT %d" % [cost, hp - cost], UiKit.RED, 11))
	_push(temper)
	var burn: Button = ui._button(temper, "Temper  ·  %d HP" % cost if hp > cost else "Too hurt to temper", func(): ui._crucible_preview(target, "temper", {}), hp > cost)
	burn.disabled = hp <= cost or _ready_locked()
	var fuse := _card(options, Color("ff8fa3"), 380)
	_title(fuse, "FUSE", 20, Color("ff8fa3"))
	ui._label(fuse, "Feed it a found gem you are not using. That gem is destroyed; a heavier one gives more.", 13, UiKit.PAPER, true)
	var fuels: Array = gems.filter(func(gem: Dictionary) -> bool: return not gem.get("equipped", false) and gem.get("found", false) and str(gem.get("id", "")) != crucible_target)
	if fuels.is_empty():
		ui._label(fuse, "You hold no unsocketed found gem to feed it.", 13, UiKit.MUTED, true)
	for fuel in fuels:
		var bonus := gain + int(floor(float(int(fuel.get("carat", 1))) / float(int(EngineScript.CRUCIBLE_FUSE_DIVISOR))))
		var row: HBoxContainer = ui._hbox(fuse, 8)
		var badge := GemBadge.make(fuel, 40)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
		var label: Label = ui._label(row, ui._gem_name(fuel), 13, ui._gem_color(fuel))
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var weight := _carat_mark(row, int(fuel.get("carat", 1)), 13, ui.GemPanel.PROPERTY_TINTS.carat)
		weight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui._button(row, "Fuse  ·  +%d Carat" % bonus, func(): ui._crucible_preview(target, "fuse", fuel)).disabled = _ready_locked()
	_footer(footer, "Leave the crucible")

# --- a treasure cache ---------------------------------------------------------------------

func _treasure(body: VBoxContainer, footer: HBoxContainer) -> void:
	var cache: Dictionary = _room().get("treasure", {}).get(ui.controlled_id, {})
	var key := "treasure:" + str(_room().get("id", ""))
	var flow := _flow(body)
	var purse := _card(flow, UiKit.GOLD, 240)
	_centred(UiKit.icon(purse, Forge.prop("gold"), 80))
	var amount := _title(purse, "+%d ORE" % int(cache.get("ore", 0)), 30, UiKit.GOLD)
	ui.reveal.count(amount, key, 0.35, int(cache.get("ore", 0)), "+%d ORE")
	ui.reveal.show(purse.get_parent(), key, 0.2, "pop")
	ui.reveal.cue(key, 0.35, ui._sound("coins"))
	_title(purse, "Loose coin in the dust, and all of it yours.", 13, UiKit.MUTED)
	var gems: Array = cache.get("gems", [])
	for index in gems.size():
		var gem: Dictionary = gems[index]
		var at := 0.8 + 0.6 * index
		var front: VBoxContainer = ui._reveal_card(flow, key, at, ui._gem_color(gem), 300)
		ui._gem_card_face(front, gem)
		for owned in _hero().get("gems", []):
			if str(owned.get("id", "")) == str(gem.get("id", "")):
				if owned.get("equipped", false): ui._socket_note(front, str(owned.id))
				else: _centred(UiKit.chip(front, "IN RESERVE  ·  YOUR SOCKETS ARE FULL", UiKit.AMBER))
		ui.reveal.cue(key, at + 0.25, ui._sound("flourish" if int(Catalog.SKILLS.get(str(gem.get("key", "")), {}).get("rarity", 1)) >= 3 else "sparkle"))
	ui.reveal.show(ui._label(body, "Appraised finds are still at risk if the party falls.", 13, UiKit.MUTED, true), key, 0.8 + 0.6 * gems.size(), "fade")
	_footer(footer, "Move on")

# --- the lift ---------------------------------------------------------------------------

func _lift(body: VBoxContainer, footer: HBoxContainer) -> void:
	var hero := _hero()
	var voted := str(ui.snapshot.get("votes", {}).get(ui.controlled_id, ""))
	var flow := _flow(body, 16)
	var ride := _card(flow, UiKit.GREEN, 470, voted == "ride", 0)
	var ride_head: HBoxContainer = ui._hbox(ride, 12)
	UiKit.icon(ride_head, Forge.room("lift"), 72)
	var ride_words: VBoxContainer = ui._vbox(ride_head, 4)
	ride_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._label(ride_words, "RIDE UP", 26, UiKit.GREEN)
	ui._label(ride_words, "End the expedition. Everything the party carries comes home to the appraisal table.", 14, UiKit.PAPER, true)
	var haul: Array = hero.get("haul", [])
	var finds: Array = hero.get("gems", []).filter(func(gem: Dictionary) -> bool: return gem.get("found", false))
	ui._label(ride, "YOUR HAUL  ·  %d UNAPPRAISED  ·  %d APPRAISED" % [haul.size(), finds.size()], 11, UiKit.GOLD)
	var shelf := _flow(ride, 6)
	for item in (haul + finds).slice(0, 16):
		var badge := GemBadge.make(item, 38)
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		badge.tooltip_text = ui._stone_words(item) if ui._sealed(item) else ui._gem_name(item)
		shelf.add_child(badge)
	if haul.is_empty() and finds.is_empty():
		ui._label(ride, "Nothing yet. Your loadout always comes home.", 13, UiKit.MUTED, true)
	_voters(ride, "ride")
	_push(ride)
	var up: Button = ui._button(ride, ("Vote to ride up" if ui._party_choice() else "Ride up") if voted.is_empty() else ("Voted  ✓" if voted == "ride" else "You voted to dig"), func(): ui._command("VoteLift", {"choice": "ride"}), true)
	up.disabled = not voted.is_empty()
	var dig := _card(flow, UiKit.AMBER, 470, voted == "dig", 1)
	var dig_head: HBoxContainer = ui._hbox(dig, 12)
	UiKit.icon(dig_head, Forge.room("mine"), 72)
	var dig_words: VBoxContainer = ui._vbox(dig_head, 4)
	dig_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._label(dig_words, "KEEP DIGGING", 26, UiKit.AMBER)
	ui._label(dig_words, "Deeper layers hold harder fights and richer stones. The next lift may be a long way down.", 14, UiKit.PAPER, true)
	var mine: Dictionary = Catalog.mine_definition(str(ui.snapshot.get("mine_id", "")))
	ui._label(dig, "DEPTH %d  ·  THE TREMORS" % int(ui.snapshot.get("depth", 0)), 11, UiKit.GOLD)
	var meter := TremorMeter.new()
	meter.reduced_motion = bool(ui.settings.reduced_motion)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dig.add_child(meter)
	meter.set_tremor(int(ui.snapshot.get("tremor", 0)), str(Catalog.definitions("enemies").get(mine.get("boss_id", ""), {}).get("name", "The boss")))
	_voters(dig, "dig")
	_push(dig)
	var down: Button = ui._button(dig, ("Vote to keep digging" if ui._party_choice() else "Keep digging") if voted.is_empty() else ("Voted  ✓" if voted == "dig" else "You voted to ride"), func(): ui._command("VoteLift", {"choice": "dig"}))
	down.disabled = not voted.is_empty()
	if ui._party_choice():
		ui._label(body, "The party decides together; a tie follows the host.", 13, UiKit.MUTED, true)
	_footer(footer, "", false, false)

# --- a vein -----------------------------------------------------------------------------

func _mine_vote(body: VBoxContainer, footer: HBoxContainer) -> void:
	var voted := str(ui.snapshot.get("votes", {}).get(ui.controlled_id, ""))
	_section(body, "CHOOSE A VEIN", UiKit.GREEN, "The party chooses together." if ui._party_choice() else "")
	var flow := _flow(body, 16)
	var index := 0
	for vein in ["coin", "crystal"]:
		var spec: Dictionary = VEINS[vein]
		var card := _card(flow, spec.tone, 470, voted == vein, index)
		index += 1
		ui._label(card, str(spec.name), 26, spec.tone)
		ui._label(card, str(spec.text), 14, UiKit.PAPER, true)
		var tags := _flow(card, 6)
		for tag in spec.tags: UiKit.chip(tags, str(tag).to_upper(), Color(spec.tone).lightened(0.2), 11)
		ui._label(card, "WHAT THE ROCK IS MADE OF", 11, UiKit.MUTED)
		_rock_bar(card, spec.weights)
		_voters(card, vein)
		_push(card)
		var choose: Button = ui._button(card, ("Vote for the " if ui._party_choice() else "Work the ") + str(spec.name) if voted.is_empty() else ("Voted  ✓" if voted == vein else "Voted for the other vein"), func(): ui._command("VoteVein", {"vein": vein}), true)
		choose.disabled = not voted.is_empty()
	_section(body, "THE PARTY'S STRENGTH", UiKit.GREEN, "One swing for each point. The fallen cannot dig.")
	var strength := _flow(body, 10)
	for hero in ui.snapshot.get("heroes", []):
		var energy := 10
		for relic in hero.get("relics", []):
			if relic.get("key") == "MINERS_LANTERN" and relic.get("equipped", false): energy += 2
		if int(hero.get("hp", 0)) <= 0: energy = 0
		var tile := _card(strength, UiKit.GREEN, 230)
		var row: HBoxContainer = ui._hbox(tile, 8)
		UiKit.icon(row, Forge.unit(str(hero.get("key", ""))), 40)
		var words: VBoxContainer = ui._vbox(row, 2)
		ui._label(words, str(hero.get("player_name", hero.get("name", "Hero"))), 15, UiKit.PAPER)
		ui._label(words, "%d swings" % energy, 13, UiKit.GREEN if energy > 0 else UiKit.RED)
	_footer(footer, "", false, false)

func _rock_bar(parent: Node, weights: Array) -> void:
	var kinds := ["Small", "Medium", "Large", "Gold", "Shiny"]
	var total := 0
	for weight in weights: total += int(weight)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var x := 0.0
		for index in kinds.size():
			var span := bar.size.x * float(weights[index]) / float(maxi(1, total))
			if span <= 0.0: continue
			bar.draw_rect(Rect2(x, 0, span - 2.0, bar.size.y), ROCK_TONES[kinds[index]])
			x += span)
	parent.add_child(bar)
	var legend := _flow(parent, 10)
	for index in kinds.size():
		if int(weights[index]) <= 0: continue
		var item: HBoxContainer = ui._hbox(legend, 4)
		var swatch := ColorRect.new()
		swatch.color = ROCK_TONES[kinds[index]]
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		ui._label(item, "%s %d%%" % [kinds[index], roundi(100.0 * float(weights[index]) / float(maxi(1, total)))], 12, UiKit.PAPER)

func _mine_dig(body: VBoxContainer, footer: HBoxContainer) -> void:
	var mine: Dictionary = ui.snapshot.get("mine", {})
	var events: Array = mine.get("events", [])
	var playing: bool = ui.mine_playback_index < events.size()
	var split: HBoxContainer = ui._hbox(body, 14)
	var pit := PanelContainer.new()
	pit.add_theme_stylebox_override("panel", UiKit.panel_box(Color("17281f"), Color("0b140f"), Color(UiKit.GREEN, 0.4), 12, 12, 1.4, 0.1))
	pit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(pit)
	var view := MineView.new()
	view.rocks = mine.get("rocks", [])
	view.events = events
	view.reduced = bool(ui.settings.reduced_motion)
	view.index_source = func() -> int: return ui.mine_playback_index
	for hero in ui.snapshot.get("heroes", []):
		view.heroes[str(hero.get("id", ""))] = {"name": str(hero.get("player_name", hero.get("name", "Hero")))}
	view.custom_minimum_size.y = 250
	pit.add_child(view)
	var tally := _card(split, UiKit.GOLD, 250)
	ui._label(tally, "THE YIELD", 12, UiKit.GOLD)
	if playing:
		_title(tally, "Digging…", 22, UiKit.PAPER)
		ui._label(tally, "Every swing was decided the moment the vein was chosen; this is the party working through them.", 13, UiKit.MUTED, true)
	else:
		var ore := int(mine.get("ore", 0))
		_title(tally, "%d ORE" % ore, 30, UiKit.GOLD)
		var heroes: int = maxi(1, ui.snapshot.get("heroes", []).size())
		ui._label(tally, "Shared: %d each%s." % [ore / heroes, "" if ore % heroes == 0 else ", the remainder by seat"], 13, UiKit.PAPER, true)
		var stones: int = mine.get("pool", []).size()
		_title(tally, "%d STONE%s" % [stones, "" if stones == 1 else "S"], 22, UiKit.VIOLET)
	var pool: Array = mine.get("pool", [])
	if playing:
		var skip: Button = ui._button(footer, "Skip  [%s]" % ui._binding_name("rd_skip"), ui._skip_playback)
		skip.tooltip_text = "Show the rest of the digging at once."
		_footer(footer, "", false, false)
		return
	if pool.is_empty():
		if ui.snapshot.get("phase", "") == "mine_draft":
			_footer(footer, "", false, false)
		else:
			_note(body, "The stones are shared out. Rearrange your equipment, then move on.", UiKit.GREEN)
			_footer(footer, "Leave the vein")
		return
	var picker := str(mine.get("picker_id", ""))
	var yours: bool = picker == str(ui.controlled_id)
	var turn_row: HBoxContainer = ui._hbox(body, 10)
	for hero in ui.snapshot.get("heroes", []):
		if str(hero.get("id", "")) == picker:
			UiKit.icon(turn_row, Forge.unit(str(hero.get("key", ""))), 40)
	ui._label(turn_row, "YOUR PICK" if yours else "%s IS PICKING" % ui._unit_name(picker).to_upper(), 20, UiKit.GOLD if yours else UiKit.AMBER).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui._label(turn_row, "The party takes turns choosing, by eye, until the stones are gone.", 13, UiKit.MUTED, true).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var flow := _flow(body)
	for index in pool.size():
		var claim: Dictionary = pool[index]
		var stone: Dictionary = claim.get("gem", {})
		var card := _card(flow, ui._gem_color(stone), 230, false, index)
		_centred(ui._gem_portrait(card, stone, 80))
		_title(card, "Unappraised %s stone" % str(Catalog.color_definition(str(stone.get("key", ""))).get("name", "")).to_lower(), 15, ui._gem_color(stone))
		ui._label(card, ui._stone_words(stone), 13, UiKit.MUTED, true)
		_push(card)
		var take: Button = ui._button(card, "Take this stone" if yours else "Waiting for %s" % ui._unit_name(picker), func(): ui._command("DraftGem", {"claim_id": claim.claim_id}), yours)
		take.disabled = not yours
	_footer(footer, "", false, false)
