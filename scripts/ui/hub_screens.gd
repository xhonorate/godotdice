extends RefCounted
## Everything the shop's objects open: the gem sack, the jeweller's stock, the commission
## board, the armor stand, the map of the deeps, the mine cart and the door.
##
## Each screen is a full-screen panel built with the main screen's own widgets, and each one
## rebuilds itself after a change rather than patching what is on screen, the same way the
## rest of the interface works. Profile changes go through the profile store as transactions;
## party changes go through the session.

const Catalog = preload("res://scripts/core/catalog.gd")
const Profile = preload("res://scripts/core/profile.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Forge = preload("res://scripts/ui/sprite_forge.gd")
const AtlasMap = preload("res://scripts/ui/atlas_map.gd")
const GemView = preload("res://scripts/ui/gem_view.gd")
const GemBadge = preload("res://scripts/ui/gem_badge.gd")
const ItemBoard = preload("res://scripts/ui/item_board.gd")
const RARITY_NAMES := ["", "Common", "Uncommon", "Rare", "Legendary"]

var ui: Control
var sort_mode := "rarity"
var filter_mode := "all"
var viewing_hero := ""

func _init(owner: Control) -> void:
	ui = owner

func today() -> String:
	return Time.get_date_string_from_system()

func open(id: String) -> void:
	match id:
		"jewel_bag": collection()
		"shopkeeper", "counter": shop()
		"commission_board": commissions()
		"armor_stand": heroes()
		"wall_map": atlas()
		"mine_cart": set_out()
		"door": party()
		"ledger": ui._show_journal()
		"clock": ui._show_settings()

func _transact(action: Callable) -> Dictionary:
	var outcome: Dictionary = ui.profile_store.transact(action)
	if not outcome.get("ok", false) and not str(outcome.get("error", "")).is_empty():
		ui._notify(str(outcome.error))
	return outcome

# --- the gem sack ---------------------------------------------------------------

func collection() -> void:
	var profile: Dictionary = ui._profile()
	var box: VBoxContainer = ui._modal("Your gem sack")
	var owned: int = profile.get("collection", {}).size()
	ui._label(box, "%d of %d gems owned  ·  %d seen. A silhouette is a gem you have never laid eyes on; a pale one you have seen but do not own." % [owned, Catalog.SKILLS.size(), profile.get("seen_gems", []).size()], 14, ui.MUTED, true)
	var controls: HBoxContainer = ui._hbox(box, 8)
	ui._label(controls, "SORT", 11, ui.GOLD)
	for mode in ["rarity", "color", "name", "owned"]:
		var button: Button = ui._button(controls, mode.capitalize(), func(): sort_mode = mode; collection())
		button.toggle_mode = true
		button.button_pressed = sort_mode == mode
	ui._spacer(controls)
	ui._label(controls, "SHOW", 11, ui.GOLD)
	for mode in ["all", "owned", "seen", "unseen"]:
		var button: Button = ui._button(controls, mode.capitalize(), func(): filter_mode = mode; collection())
		button.toggle_mode = true
		button.button_pressed = filter_mode == mode
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for row in Profile.collection_grid(profile, sort_mode):
		if filter_mode != "all" and row.state != filter_mode:
			continue
		_collection_card(grid, row)

func _collection_card(parent: Node, row: Dictionary) -> void:
	var state := str(row.state)
	var accent := Color(str(Catalog.GEM_COLORS.get(row.color, {}).get("hex", "8f9fb5")))
	var card: VBoxContainer = ui._panel(parent, ui.PANEL if state != "unseen" else ui.PANEL_LOW, Color(accent, 0.6) if state == "owned" else ui.LINE, 10)
	card.custom_minimum_size = Vector2(170, 196)
	var sample: Dictionary = row.gem if state == "owned" else Catalog.gem(str(row.key), "sack-" + str(row.key), 8, 3, 3)
	# Flat badges, not solids: a sack of thirty-odd live 3D cameras was the slowest screen in
	# the shop. "Look closer" still opens the stone in 3D.
	var badge := GemBadge.make(sample, 96, state)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(badge)
	var name_label: Label = ui._label(card, str(row.name) if state != "unseen" else "???", 15, accent if state == "owned" else ui.MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detail := ""
	match state:
		"owned": detail = "C%d  ·  %s  ·  %s" % [int(row.gem.carat), Catalog.cut_name(int(row.gem.cut)), Catalog.clarity_name(int(row.gem.clarity))]
		"seen": detail = "%s  ·  not owned" % RARITY_NAMES[clampi(int(row.rarity), 1, 4)]
		_: detail = "Not yet found"
	var detail_label: Label = ui._label(card, detail, 11, ui.PAPER if state == "owned" else ui.MUTED)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if state == "owned":
		ui._button(card, "Look closer", func(): _gem_sheet(row.gem, collection))
	elif state == "seen":
		ui._button(card, "Read", func(): _gem_sheet(sample, collection, false))

func _gem_sheet(gem: Dictionary, back: Callable, owned := true) -> void:
	var box: VBoxContainer = ui._modal(ui._gem_name(gem))
	var holder := Control.new()
	var view: Control = ui._gem_portrait(holder, gem, 220)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(view as GemView).enable_interaction()
	var body: VBoxContainer = ui._sheet(box, holder, Vector2(220, 220), ui._gem_color(gem))
	var definition: Dictionary = Catalog.SKILLS.get(str(gem.get("key", "")), {})
	ui._label(body, ui._gem_name(gem), 26, ui._gem_color(gem))
	if owned:
		ui._gem_title_row(body, gem, 16, ui.PAPER, false)
	ui._label(body, "%s  ·  %s gem — %s." % [RARITY_NAMES[clampi(int(definition.get("rarity", 1)), 1, 4)], str(Catalog.color_definition(str(gem.get("key", ""))).get("name", "")), str(Catalog.color_definition(str(gem.get("key", ""))).get("role", "")).to_lower()], 14, ui.MUTED, true)
	ui._label(body, str(definition.get("trigger", "")), 15, ui.GREEN, true)
	if owned:
		ui._formula_rows(body, gem, -1, 15)
		ui._label(body, "Worth %d gold." % Profile.sell_value(gem), 14, ui.GOLD)
	else:
		ui._label(body, str(definition.get("formula", "")), 14, ui.PAPER, true)
		ui._label(body, "You have seen one of these but do not own it. The jeweller may stock it.", 14, ui.MUTED, true)
	ui._button(box, "Back", back)

# --- the jeweller ----------------------------------------------------------------

func shop() -> void:
	_transact(func(profile: Dictionary) -> String:
		Profile.ensure_shop(profile, today())
		return "")
	var profile: Dictionary = ui._profile()
	var box: VBoxContainer = ui._modal("Old Garnet's display case")
	var head: HBoxContainer = ui._hbox(box, 12)
	UiKit.icon(head, Forge.prop("gold"), 40).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var words: VBoxContainer = ui._vbox(head, 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._label(words, "\"Only stones you'd know if you saw them. Fresh stock every morning.\"", 17, ui.PAPER, true)
	ui._label(words, "You carry %d gold. The case restocks at midnight — in %s." % [int(profile.gold), _until_midnight()], 14, ui.MUTED, true)
	var stock: Array = profile.get("shop", {}).get("stock", [])
	if stock.is_empty():
		ui._label(box, "The case is empty. Garnet only sells gems you have already seen, and nothing you own a better copy of. Bring more home from the mines.", 15, ui.AMBER, true)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for offer in stock:
		var gem: Dictionary = offer.gem
		var card: VBoxContainer = ui._panel(grid, ui.PANEL, Color(ui._gem_color(gem), 0.5) if not offer.sold else ui.LINE, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui._gem_details(card, gem)
		var owned_copy: Dictionary = profile.collection.get(gem.key, {})
		if not owned_copy.is_empty():
			ui._label(card, "Yours: C%d K%d L%d — this one is worth %d gold more." % [int(owned_copy.carat), int(owned_copy.cut), int(owned_copy.clarity), Profile.sell_value(gem) - Profile.sell_value(owned_copy)], 12, ui.GREEN, true)
		var short: int = int(offer.price) - int(profile.gold)
		var caption := "Sold" if offer.sold else ("Need %d more gold" % short if short > 0 else "Buy  ·  %d gold" % int(offer.price))
		var buy: Button = ui._button(card, caption, func():
			var outcome := _transact(func(working: Dictionary) -> Dictionary: return Profile.buy_offer(working, str(offer.id), today()))
			if outcome.get("ok", false):
				ui._notify("%s joins your collection." % ui._gem_name(gem) + (" Your old one sold for %d gold." % int(outcome.gold) if int(outcome.get("gold", 0)) > 0 else ""))
			shop(), true)
		buy.disabled = offer.sold or short > 0
	UiKit.rule(box)
	var row: HBoxContainer = ui._hbox(box, 12)
	var cost := Profile.refresh_cost(profile)
	var restock: Button = ui._button(row, "Restock now  ·  %d gold" % cost, func():
		_transact(func(working: Dictionary) -> String: return Profile.refresh_shop(working, today()))
		shop())
	restock.disabled = int(profile.gold) < cost
	ui._label(row, "Each restock today costs 1000 gold more than the last. The price resets at midnight.", 13, ui.MUTED, true)

func _until_midnight() -> String:
	var now: Dictionary = Time.get_time_dict_from_system()
	var left: int = 86400 - (int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second))
	return "%dh %02dm" % [left / 3600, (left % 3600) / 60]

# --- the commission board --------------------------------------------------------------

func commissions() -> void:
	_transact(func(profile: Dictionary) -> String:
		Profile.ensure_commissions(profile, today())
		return "")
	var profile: Dictionary = ui._profile()
	var box: VBoxContainer = ui._modal("The commission board")
	ui._label(box, "Buyers pin their wants here. Bring the right stone home — or do the deed — and the reward is yours to claim. A claimed note is replaced by a new one.", 14, ui.MUTED, true)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for note in profile.get("commissions", {}).get("board", []):
		_note_card(grid, note, false)
	var specials: Array = profile.get("commissions", {}).get("special", [])
	ui._label(box, "SPECIAL CONTRACTS", 12, ui.RED)
	if specials.is_empty():
		ui._label(box, "No special contract is posted today. They come and go with the days.", 14, ui.MUTED, true)
	for note in specials:
		_note_card(box, note, true)

func _note_card(parent: Node, note: Dictionary, special: bool) -> void:
	var complete: bool = note.get("status", "") == "complete"
	var card: VBoxContainer = ui._panel(parent, Color("2a2418") if not special else Color("2e1a1a"), ui.GREEN if complete else (ui.RED if special else ui.LINE), 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 300
	ui._label(card, Profile.describe_commission(note), 16, ui.PAPER, true)
	if special:
		var modifier: Dictionary = Profile.SPECIAL_MODIFIERS.get(str(note.get("modifier", "")), {})
		ui._label(card, "%s: %s" % [str(modifier.get("name", "")), str(modifier.get("description", ""))], 13, ui.AMBER, true)
		ui._label(card, "Posted until the end of %s." % str(note.get("expires", "")), 12, ui.MUTED)
	var reward: Dictionary = note.get("reward", {})
	var reward_row: HBoxContainer = ui._hbox(card, 8)
	UiKit.chip(reward_row, "%d GOLD" % int(reward.get("gold", 0)), ui.GOLD)
	if not reward.get("gem", {}).is_empty():
		UiKit.chip(reward_row, "+ " + ui._gem_name(reward.gem).to_upper(), ui._gem_color(reward.gem))
	if complete:
		ui._button(card, "Claim the reward", func():
			var outcome := _transact(func(working: Dictionary) -> Dictionary: return Profile.claim_commission(working, str(note.id)))
			if outcome.get("ok", false): ui._notify("Claimed %d gold%s." % [int(outcome.gold), " and " + ui._gem_name(outcome.gem) if not outcome.get("gem", {}).is_empty() else ""])
			commissions(), true)
	elif special:
		var taken: bool = ui.special_choice.get("id", "") == str(note.id)
		var take: Button = ui._button(card, "Contract taken — the cart is set for %s" % str(Catalog.mine_definition(str(note.mine_id)).get("name", "")) if taken else "Take the contract", func():
			ui.special_choice = {} if taken else {"id": str(note.id), "modifier": str(note.modifier), "mine_id": str(note.mine_id)}
			if not taken: ui._choose_mine(str(note.mine_id))
			commissions(), not taken)
		take.disabled = not ui._choosing_destination() or Profile.mine_state(ui._profile(), str(note.mine_id)) != "unlocked"
		if not ui._choosing_destination(): take.tooltip_text = "The host of the party chooses where it digs."
	else:
		ui._label(card, "Open", 12, ui.MUTED)

# --- the armor stand ------------------------------------------------------------------

func heroes() -> void:
	var profile: Dictionary = ui._profile()
	if viewing_hero.is_empty(): viewing_hero = ui.menu_hero.to_upper()
	var box: VBoxContainer = ui._modal("The armor stand")
	var picker: HBoxContainer = ui._hbox(box, 10)
	var keys: Array = Catalog.definitions("heroes").keys()
	keys.sort()
	for key in keys:
		var record: Dictionary = profile.get("heroes", {}).get(key, {})
		var locked: bool = not record.get("unlocked", false)
		var tile: VBoxContainer = ui._panel(picker, ui.PANEL_HI if key == viewing_hero else ui.PANEL, ui.GOLD if key == viewing_hero else ui.LINE, 10)
		var icon := UiKit.icon(tile, Forge.unit(key), 72)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if locked: icon.modulate = Color(0, 0, 0, 0.85)
		ui._label(tile, "???" if locked else str(Catalog.definitions("heroes")[key].name), 14, ui.MUTED if locked else ui.PAPER).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var choose: Button = ui._button(tile, "Locked" if locked else ("Viewing" if key == viewing_hero else "View"), func(): viewing_hero = key; heroes())
		choose.disabled = locked
	var definition: Dictionary = Catalog.definitions("heroes").get(viewing_hero, {})
	var record: Dictionary = profile.get("heroes", {}).get(viewing_hero, {})
	var main: HBoxContainer = ui._hbox(box, 20)
	var figure: VBoxContainer = ui._panel(main, ui.PANEL, ui.LINE, 14)
	UiKit.icon(figure, Forge.unit(viewing_hero), 180).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ui._label(figure, str(definition.get("name", "")), 26, ui.GOLD)
	ui._label(figure, "%d HP  ·  %s" % [int(definition.get("max_hp", 0)), ui._join_values(definition.get("dice", []))], 14, ui.GREEN)
	ui._label(figure, "%s: %s" % [str(definition.get("trait_name", "")), str(definition.get("description", ""))], 13, ui.MUTED, true)
	figure.custom_minimum_size.x = 300
	var chosen: bool = ui.menu_hero.to_upper() == viewing_hero
	ui._button(figure, "This hero goes down the mine" if chosen else "Take this hero on the next expedition", func():
		ui._choose_hero(viewing_hero)
		heroes(), not chosen).disabled = chosen
	var sockets: VBoxContainer = ui._vbox(main, 8)
	sockets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var loadout: Array = record.get("loadout", [])
	var socketed: Array = []
	for key in loadout:
		if profile.collection.has(key):
			socketed.append(_owned(profile, key))
	var reserve: Array = []
	var owned_keys: Array = profile.collection.keys()
	owned_keys.sort_custom(func(a: String, b: String) -> bool:
		var ra := int(Catalog.SKILLS.get(a, {}).get("rarity", 1))
		var rb := int(Catalog.SKILLS.get(b, {}).get("rarity", 1))
		return ra > rb if ra != rb else a < b)
	for key in owned_keys:
		if not key in loadout:
			reserve.append(_owned(profile, key))
	ItemBoard.build(ui, sockets, {
		"kind": "loadout", "title": "LOADOUT  ·  SIX SOCKETS", "slots": Profile.LOADOUT_SLOTS, "socketed": socketed, "reserve": reserve, "edge": 64,
		"hint": "Left to right is the order they resolve. Drag gems in, out and between sockets; double-click to set or take one off.",
		"reserve_title": "YOUR COLLECTION  ·  %d GEMS" % profile.collection.size(),
		"empty_reserve": "Every gem you own is socketed. Bring more home, or buy from the jeweller.",
		"art": func(gem: Dictionary, holder: Control, edge: float):
			var badge := GemBadge.make(gem, edge)
			badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			holder.add_child(badge),
		"caption": func(gem: Dictionary) -> String: return str(Catalog.SKILLS.get(gem.key, {}).get("name", gem.key)),
		"tint": func(gem: Dictionary) -> Color: return ui._gem_color(gem),
		"tip": func(gem: Dictionary) -> String: return "%s\nC%d  ·  %s  ·  %s\n%s" % [str(Catalog.SKILLS.get(gem.key, {}).get("name", gem.key)), int(gem.carat), Catalog.cut_name(int(gem.cut)), Catalog.clarity_name(int(gem.clarity)), str(Catalog.SKILLS.get(gem.key, {}).get("trigger", ""))],
		"pinned": func(gem: Dictionary) -> String: return "Strike stays in every loadout." if gem.key == "STRIKE" else "",
		"place": func(gem: Dictionary, index: int, occupant: Dictionary):
			var next := loadout.duplicate()
			if not occupant.is_empty():
				if occupant.key == "STRIKE":
					ui._notify("Strike stays in every loadout. Drop this one on another socket.")
					return
				next[next.find(occupant.key)] = gem.key
			elif next.size() >= Profile.LOADOUT_SLOTS:
				ui._notify("All six sockets are full. Drop it onto the gem it should replace.")
				return
			else:
				next.append(gem.key)
			_set_loadout(next),
		"move": func(from: int, to: int):
			var next := loadout.duplicate()
			var held = next[from]
			next[from] = next[to]
			next[to] = held
			_set_loadout(next),
		"remove": func(gem: Dictionary):
			var next := loadout.duplicate()
			next.erase(gem.key)
			_set_loadout(next),
		"inspect": func(gem: Dictionary): _gem_sheet(gem, heroes)})

func _owned(profile: Dictionary, key: String) -> Dictionary:
	## A collection record as a board item: the key doubles as its id.
	var gem: Dictionary = profile.collection[key].duplicate()
	gem["id"] = key
	return gem

func _set_loadout(keys: Array) -> void:
	_transact(func(profile: Dictionary) -> String: return Profile.set_loadout(profile, viewing_hero, keys))
	ui._sync_lobby_identity()
	heroes()

# --- the map of the deeps ----------------------------------------------------------------

func atlas() -> void:
	var profile: Dictionary = ui._profile()
	var box: VBoxContainer = ui._modal("The map of the deeps")
	var row: HBoxContainer = ui._hbox(box, 18)
	var map := AtlasMap.new()
	map.reduced_motion = bool(ui.settings.reduced_motion)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size = Vector2(560, 460)
	row.add_child(map)
	var specials: Array = profile.get("commissions", {}).get("special", []).map(func(note: Dictionary) -> String: return str(note.mine_id))
	map.configure(profile, ui.mine_choice, specials)
	map.mine_selected.connect(func(id: String): ui.atlas_focus = id; atlas())
	var focus: String = ui.atlas_focus if not ui.atlas_focus.is_empty() else ui.mine_choice
	var side: VBoxContainer = ui._panel(row, ui.PANEL, ui.LINE, 16)
	side.custom_minimum_size.x = 420
	_mine_preview(side, focus)

func _mine_preview(parent: VBoxContainer, mine_id: String) -> void:
	var profile: Dictionary = ui._profile()
	var mine: Dictionary = Catalog.mine_definition(mine_id)
	var state := Profile.mine_state(profile, mine_id)
	if mine.is_empty() or state == "hidden":
		ui._label(parent, "Pick a mine on the map.", 16, ui.MUTED)
		return
	if state != "unlocked":
		ui._label(parent, "Uncharted", 26, ui.MUTED)
		ui._label(parent, "Word of a mine lies this way, but the path is closed. Kill the boss of a neighbouring mine to open it.", 15, ui.MUTED, true)
		return
	var record: Dictionary = profile.get("mines", {}).get(mine_id, {})
	ui._label(parent, str(mine.name), 28, Color(str(mine.get("color", "c9a26b"))))
	ui._label(parent, "Difficulty  " + "◆".repeat(int(mine.difficulty)) + "◇".repeat(5 - int(mine.difficulty)), 15, ui.AMBER)
	ui._label(parent, str(mine.get("description", "")), 14, ui.PAPER, true)
	var boss_key := str(mine.get("boss_id", ""))
	var met: bool = boss_key in profile.get("encountered", {}).get("bosses", [])
	var boss_row: HBoxContainer = ui._hbox(parent, 10)
	var boss_icon := UiKit.icon(boss_row, Forge.unit(boss_key), 72)
	if not met: boss_icon.modulate = Color(0, 0, 0, 0.85)
	var boss_text: VBoxContainer = ui._vbox(boss_row, 2)
	ui._label(boss_text, str(Catalog.definitions("enemies").get(boss_key, {}).get("name", "")) if met else "An unseen boss", 18, ui.RED if met else ui.MUTED)
	ui._label(boss_text, "Defeated" if record.get("boss_defeated", false) else ("Met, not yet beaten" if met else "Waits where the tremors lead"), 12, ui.GREEN if record.get("boss_defeated", false) else ui.MUTED)
	ui._label(parent, "Deepest reached: %d  ·  expeditions: %d" % [int(record.get("deepest", 0)), int(record.get("expeditions", 0))], 13, ui.BLUE)
	var rooms: Dictionary = mine.get("rooms", {})
	var ranked: Array = rooms.keys()
	ranked.sort_custom(func(a: String, b: String) -> bool: return int(rooms[a]) > int(rooms[b]))
	var rooms_row: HBoxContainer = ui._hbox(parent, 6)
	ui._label(rooms_row, "Often:", 12, ui.MUTED)
	for kind in ranked.slice(0, 4):
		UiKit.icon(rooms_row, Forge.room(kind), 28).tooltip_text = kind.capitalize()
	ui._label(parent, "GEMS FOUND HERE", 11, ui.GOLD)
	var pool := HFlowContainer.new()
	pool.add_theme_constant_override("h_separation", 4)
	parent.add_child(pool)
	for key in mine.get("skill_ids", []):
		var seen: bool = key in profile.get("seen_gems", [])
		var owned: bool = profile.get("collection", {}).has(key)
		var badge := GemBadge.make(profile.collection[key] if owned else Catalog.gem(key, "atlas-" + key, 6, 3, 3), 40, "owned" if owned else ("seen" if seen else "unseen"))
		badge.sized = false
		badge.mouse_filter = Control.MOUSE_FILTER_PASS
		badge.tooltip_text = (str(Catalog.SKILLS.get(key, {}).get("name", key)) + ("  ·  owned" if owned else "  ·  seen, not owned")) if seen else "A gem you have not seen yet"
		pool.add_child(badge)
	var chosen: bool = ui.mine_choice == mine_id
	var choose: Button = ui._button(parent, "The cart is set for this mine" if chosen else "Set the cart for this mine", func():
		ui._choose_mine(mine_id)
		atlas(), not chosen)
	choose.disabled = chosen or not ui._choosing_destination()
	if not ui._choosing_destination():
		ui._label(parent, "The host of the party chooses where it digs.", 13, ui.AMBER, true)

# --- the mine cart ---------------------------------------------------------------------

func set_out() -> void:
	var profile: Dictionary = ui._profile()
	var box: VBoxContainer = ui._modal("The mine cart")
	var row: HBoxContainer = ui._hbox(box, 18)
	var hero_key: String = ui.menu_hero.to_upper()
	var hero_panel: VBoxContainer = ui._panel(row, ui.PANEL, ui.LINE, 14)
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._label(hero_panel, "YOUR HERO", 11, ui.GOLD)
	var hero_row: HBoxContainer = ui._hbox(hero_panel, 10)
	UiKit.icon(hero_row, Forge.unit(hero_key), 84)
	var hero_text: VBoxContainer = ui._vbox(hero_row, 3)
	ui._label(hero_text, str(Catalog.definitions("heroes").get(hero_key, {}).get("name", hero_key)), 22, ui.PAPER)
	var names: Array = []
	for key in profile.get("heroes", {}).get(hero_key, {}).get("loadout", []):
		names.append(str(Catalog.SKILLS.get(key, {}).get("name", key)))
	ui._label(hero_text, " · ".join(names), 13, ui.GOLD, true)
	ui._button(hero_panel, "Change at the armor stand", heroes)
	var mine_id: String = ui._destination()
	var mine: Dictionary = Catalog.mine_definition(mine_id)
	var mine_panel: VBoxContainer = ui._panel(row, ui.PANEL, Color(str(mine.get("color", "c9a26b")), 0.6), 14)
	mine_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._label(mine_panel, "DESTINATION", 11, ui.GOLD)
	ui._label(mine_panel, str(mine.get("name", "")), 22, Color(str(mine.get("color", "c9a26b"))))
	ui._label(mine_panel, "Difficulty " + "◆".repeat(int(mine.get("difficulty", 1))), 13, ui.AMBER)
	var special: Dictionary = ui._destination_special()
	if not special.get("modifier", "").is_empty():
		ui._label(mine_panel, "Special contract: %s" % str(Profile.SPECIAL_MODIFIERS.get(special.modifier, {}).get("name", "")), 14, ui.RED, true)
	if ui._choosing_destination():
		ui._button(mine_panel, "Change on the map", atlas)
	else:
		ui._label(mine_panel, "Chosen by the host.", 13, ui.MUTED)
	var lobby: Dictionary = ui.session.lobby
	var members: Array = lobby.get("members", [])
	var networked: bool = ui._in_party()
	if networked:
		ui._label(box, "THE PARTY", 12, ui.GOLD)
		for member in members:
			var member_row: HBoxContainer = ui._hbox(box, 10)
			UiKit.icon(member_row, Forge.unit(str(member.get("hero_id", "ARDOR"))), 40)
			ui._label(member_row, str(member.get("name", "Hero")), 17, ui.PAPER)
			ui._label(member_row, "HOST" if member.get("player_id") == ui.session.host_player_id else "", 11, ui.GOLD)
			ui._spacer(member_row)
			ui._label(member_row, "READY" if member.get("ready", false) else ("DISCONNECTED" if not member.get("connected", true) else "NOT READY"), 13, ui.GREEN if member.get("ready", false) else ui.AMBER)
		var mine_ready: bool = ui._local_lobby_member().get("ready", false)
		if ui.session.is_host:
			var start: Button = ui._button(box, "Descend with the party  →", ui._begin_network, true)
			start.disabled = not ui.session.can_start()
			ui._button(box, "Unready" if mine_ready else "Ready", func(): ui.session.set_lobby_ready(not mine_ready); set_out.call_deferred())
			if not ui.session.can_start(): ui._label(box, "Every member has to be ready, the host included.", 13, ui.MUTED, true)
		else:
			ui._button(box, "Unready" if mine_ready else "Ready to descend", func(): ui.session.set_lobby_ready(not mine_ready); set_out.call_deferred(), not mine_ready)
	else:
		ui._button(box, "Descend  →", ui._begin_local, true)
		if ui.engine.save_store.has_checkpoint():
			ui._button(box, "Continue the saved expedition", ui._resume)
	var seed_row: HBoxContainer = ui._hbox(box, 8)
	ui._label(seed_row, "Seed (optional)", 12, ui.MUTED)
	var seed_edit := LineEdit.new()
	seed_edit.text = ui.seed_text
	seed_edit.placeholder_text = "Leave blank for a new seam"
	seed_edit.custom_minimum_size.x = 260
	seed_edit.text_changed.connect(func(value: String): ui.seed_text = value)
	seed_row.add_child(seed_edit)

# --- the door ---------------------------------------------------------------------------

func party() -> void:
	var box: VBoxContainer = ui._modal("The door")
	var session: Node = ui.session
	if ui._in_party():
		ui._label(box, "Your party  ·  %s  ·  %s" % [str(session.lobby.get("transport", "")).to_upper(), str(session.status)], 16, ui.GREEN, true)
		if session.lobby.has("steam_lobby_id"):
			ui._label(box, "Steam lobby ID: %s" % str(session.lobby.steam_lobby_id), 14, ui.GOLD)
		for member in session.lobby.get("members", []):
			var row: HBoxContainer = ui._hbox(box, 10)
			UiKit.icon(row, Forge.unit(str(member.get("hero_id", "ARDOR"))), 40)
			ui._label(row, str(member.get("name", "Hero")), 17, ui.PAPER)
			ui._label(row, "HOST" if member.get("player_id") == session.host_player_id else "GUEST", 11, ui.GOLD)
			ui._spacer(row)
			ui._label(row, "READY" if member.get("ready", false) else "IN THE SHOP", 12, ui.GREEN if member.get("ready", false) else ui.MUTED)
		var controls: HBoxContainer = ui._hbox(box, 10)
		if session.is_host and session.transport_kind == "steam":
			ui._button(controls, "Invite friends", func(): session.invite_friends())
		if session.is_host:
			ui._button(controls, "Reopen a saved party expedition", ui._resume_network)
		ui._button(controls, "Close the shop to visitors" if session.is_host else "Leave the party", func():
			session.leave()
			party())
		ui._label(box, "Everyone in the party can browse the shop, change heroes and loadouts, and ready up at the mine cart. The host picks the mine on the map and sends the cart down.", 14, ui.MUTED, true)
		return
	ui._label(box, "Flip the sign to let friends in, or knock on someone else's door.", 16, ui.PAPER, true)
	var name_row: HBoxContainer = ui._hbox(box, 8)
	ui._label(name_row, "Your name", 13, ui.GOLD)
	var name_edit := LineEdit.new()
	name_edit.text = ui.player_name
	name_edit.custom_minimum_size.x = 220
	name_edit.text_changed.connect(func(value: String): ui.player_name = value)
	name_row.add_child(name_edit)
	var lan: VBoxContainer = ui._panel(box, ui.PANEL, ui.LINE, 14)
	ui._label(lan, "LAN / DIRECT", 12, ui.GOLD)
	var lan_row: HBoxContainer = ui._hbox(lan, 8)
	ui._button(lan_row, "Open the shop (host)", func(): ui._open_party(func(): return session.host_enet(ui.player_name)))
	var address := LineEdit.new()
	address.text = ui.server_address
	address.placeholder_text = "Host IP address"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address.text_changed.connect(func(value: String): ui.server_address = value)
	lan_row.add_child(address)
	ui._button(lan_row, "Join", func(): ui._open_party(func(): return session.join_enet(ui.server_address, ui.player_name)))
	ui._label(lan, "LAN uses UDP port 24567.", 12, ui.MUTED)
	var steam: VBoxContainer = ui._panel(box, ui.PANEL, ui.LINE, 14)
	ui._label(steam, "STEAM", 12, ui.BLUE)
	var steam_row: HBoxContainer = ui._hbox(steam, 8)
	ui._button(steam_row, "Open a Steam lobby", func(): ui._open_party(func(): return session.host_steam(ui.player_name)))
	var steam_edit := LineEdit.new()
	steam_edit.text = ui.steam_lobby_text
	steam_edit.placeholder_text = "Steam lobby ID / invitation"
	steam_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steam_edit.text_changed.connect(func(value: String): ui.steam_lobby_text = value)
	steam_row.add_child(steam_edit)
	ui._button(steam_row, "Join Steam", func(): ui._open_party(func(): return session.join_steam(ui.steam_lobby_text, ui.player_name)))
	ui._label(steam, "Steam lobbies need the GodotSteam extension and a running Steam client.", 12, ui.MUTED)
