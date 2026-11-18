extends RefCounted
## Delvers: two views of one delver, each a page of its own. The roster strip over the dossier
## of the one being looked at (their dice, sockets, passive and Birthstone); and their sockets,
## filled from the vault. Opening a delver's sockets makes them the one going down: whoever's
## loadout was changed last is who the Descend button names.

const Roster = preload("res://view/home/roster.gd")
const StoneBrowser = preload("res://view/home/stone_browser.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Plates = preload("res://view/ui/plates.gd")
const Tips = preload("res://view/ui/tips.gd")
const DescendPage = preload("res://view/home/descend_page.gd")
const MineMap = preload("res://view/home/mine_map.gd")

## The order the socket picker last laid its stones out in, and what for: {key (the delver and
## the browser's sort), socket, order (skills)}. Setting a stone does not move the rest under
## the pointer; only picking another socket (or another sort) lays them out again (K1).
static var _pick_order: Dictionary = {}

## How many vault stones the socket picker shows a page: three rows.
const PICK_PAGE: int = 42
## How wide the dossier's Birthstone card stands: wide enough that the longest tier's words
## (Bloodroot's) fit under its three stones at the largest text, with the page's height.
const BIRTH_WIDE: float = 560.0
## When a click set a stone in the picked socket: the grid is drawn again at once, so the
## second press of a double-click lands on whatever tile now stands under the pointer, and
## must not set that one as well.
static var _set_at_msec: int = -100000

static func build(home: Control, content: VBoxContainer) -> void:
	if DeepUi.phone:
		load("res://view/phone/delvers_phone.gd").build(home, content)
		return
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	if home._roster_pick.is_empty() or DeepContent.character(home._roster_pick).is_empty():
		home._roster_pick = current
	var unlocked: Array = DeepProfile.unlocked_characters(home.profile)
	if not unlocked.has(home._roster_pick):
		home._roster_view = "dossier"
	if home._roster_view == "sockets":
		_loadout_head(home, content, home._roster_pick)
		_sockets_view(home, content, home._roster_pick)
		return
	_strip(home, content, current, unlocked)
	_dossier(home, content, home._roster_pick, unlocked.has(home._roster_pick), home._roster_pick == current)

static func _strip(home: Control, content: VBoxContainer, current: String, unlocked_keys: Array) -> void:
	var order: Array = DeepContent.characters_in_unlock_order()
	var strip_card := DeepUi.card(content, DeepUi.LINE, 14)
	var strip_box := DeepUi.vbox(strip_card, 8)
	var strip_head := DeepUi.hbox(strip_box, 8)
	DeepUi.section(strip_head, "person", "Delvers").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.stat(strip_head, "chest", "%d of %d unlocked" % [unlocked_keys.size(), order.size()], DeepUi.MUTED, 13)
	DeepUi.stat(strip_head, "crown", DeepUi.plural(Roster.wardens_beaten(home.profile), "Warden") + " beaten", DeepUi.MUTED, 13)
	var strip := DeepUi.hbox(strip_box, 12)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	var index: int = 0
	for key in order:
		var record: Dictionary = home.profile.get("characters", {}).get(str(key), {})
		var tile := Roster.tile(strip, str(key), str(key) == home._roster_pick, str(key) == current, bool(record.get("unlocked", false)), bool(record.get("fresh", false)))
		var picked_key: String = str(key)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				DeepAudio.play("ui_tap")
				home._roster_pick = picked_key
				home._bench_socket = -1
				if home.profile.get("characters", {}).has(picked_key) and bool(home.profile.characters[picked_key].get("fresh", false)):
					home.profile.characters[picked_key].erase("fresh")
					home.touch()
				home._render())
		home.enter(tile, 0.03 * index)
		index += 1

static func _loadout_head(home: Control, content: VBoxContainer, key: String) -> void:
	## Over a delver's sockets: the way back, who they are (and that they are the one going
	## down), and the dice they always take down, which are theirs and not for swapping.
	var head := DeepUi.card(content, DeepUi.LINE, 10)
	var row := DeepUi.hbox(head, 14)
	var left_slot := DeepUi.hbox(row, 0)
	left_slot.custom_minimum_size.x = 210
	left_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## The way back is the key a way back is everywhere (DeepUi.way_out, November 9, 2026).
	var back := DeepUi.way_out("Delvers", func() -> void:
		home._roster_view = "dossier"
		home._bench_socket = -1
		_pick_order = {}
		home._render(), true, "Back to the delvers (Esc)", "person")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_slot.add_child(back)
	var center_slot := CenterContainer.new()
	center_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center_slot)
	var navigation := DeepUi.hbox(center_slot, 10)
	var owned: Array = DeepProfile.unlocked_characters(home.profile)
	var previous := DeepUi.icon_button(navigation, "prev", "", func() -> void: home.step_character(-1), 14, DeepUi.MUTED)
	previous.tooltip_text = "Previous delver (Q)"
	previous.disabled = owned.size() < 2
	previous.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	navigation.add_child(Roster.Portrait.new(key, Vector2(52, 52), false, false, true))
	var names := DeepUi.vbox(navigation, 0)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.title(names, DeepContent.character_title(key), 22, DeepUi.PAPER)
	var dice := DeepUi.hbox(names, 6)
	dice.mouse_filter = Control.MOUSE_FILTER_PASS
	dice.tooltip_text = home.OWN_DICE
	for die in DeepProfile.loadout(home.profile, key).dice:
		var die_thumb := Thumbs.DieThumb.new(die, 30)
		die_thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		dice.add_child(die_thumb)
	var next := DeepUi.icon_button(navigation, "next", "", func() -> void: home.step_character(1), 14, DeepUi.MUTED)
	next.tooltip_text = "Next delver (E)"
	next.disabled = owned.size() < 2
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var right_slot := DeepUi.hbox(row, 0)
	right_slot.custom_minimum_size.x = 210
	right_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_slot.alignment = BoxContainer.ALIGNMENT_END
	var going := DeepUi.pill(right_slot, "check", "Going down", DeepUi.GOOD, 13, "Changing a delver's sockets makes them the one going down.")
	going.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	home.enter(head)

static func _dossier(home: Control, content: VBoxContainer, key: String, unlocked: bool, chosen: bool) -> void:
	## Everything about one delver: portrait, health, dice, sockets, passive, Birthstone.
	var character: Dictionary = DeepContent.character(key)
	var passive: Dictionary = character.get("passive", {})
	## The stone they wear: the page is tinted by it, and it stands at the end of their sockets.
	var stone: Dictionary = DeepStone.birthstone(key, DeepProfile.worn_birthstone(home.profile, key))
	var tint: Color = HomeParts.birth_tone(stone)
	var card := DeepUi.card(content, Color(tint if unlocked else DeepUi.LINE, 0.5), 18)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## Who they are and their kit over the page's buttons, and beside all of it, the height of
	## the page, their Birthstones: three stones and a ladder of up to six tiers want the room.
	var sides := DeepUi.hbox(card, 24)
	var box := DeepUi.vbox(sides, 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var columns := DeepUi.hbox(box, 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := DeepUi.vbox(columns, 8)
	left.custom_minimum_size.x = 250
	left.add_child(Roster.Portrait.new(key, Vector2(250, 250), not unlocked, false, chosen))
	DeepUi.title(left, str(character.get("name", key)), 30, DeepUi.PAPER if unlocked else DeepUi.DIM)
	DeepUi.label(left, str(character.get("title", "")), 15, DeepUi.MUTED)
	DeepUi.wrap(left, str(character.get("text", "")), 13, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 250)
	var middle := DeepUi.vbox(columns, 12)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pills := DeepUi.hbox(middle, 8)
	DeepUi.pill(pills, "heart", "%d health" % int(character.get("hp", 0)), DeepUi.HP, 13)
	DeepUi.pill(pills, "gem", DeepUi.plural(character.get("sockets", []).size(), "socket"), DeepUi.INFO, 13)
	if not unlocked:
		DeepUi.pill(pills, "lock", Roster.unlock_hint(key), DeepUi.DIM, 13)
	var dice_head := DeepUi.section(middle, "die", "Their dice")
	DeepUi.stat(dice_head, "lock", "always their own", DeepUi.DIM, 11, home.OWN_DICE)
	var dice_row := DeepUi.hbox(middle, 10)
	var die_index: int = 0
	for die_key in character.get("dice", []):
		var die: Dictionary = DeepForge.die_from(die_key, "roster_%s_%d" % [key, die_index])
		var holder := DeepUi.vbox(dice_row, 3)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		var thumb := Thumbs.DieThumb.new(die, 46)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.add_child(thumb)
		DeepUi.label(holder, DeepDice.describe(die), 11, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		home.faces_row(holder, die, 12)
		die_index += 1
	DeepUi.section(middle, "gem", "Their sockets")
	var socket_row := DeepUi.hbox(middle, 10)
	var open_socket: Callable = func(index: int) -> void: home.edit_loadout(key, index)
	home.socket_strip(socket_row, key, DeepProfile.loadout(home.profile, key), 46.0, true, open_socket if unlocked else Callable())
	DeepUi.section(middle, "spark", "Passive")
	var passive_card := DeepUi.card(middle, Color(DeepUi.ACCENT, 0.35), 12)
	var passive_box := DeepUi.vbox(passive_card, 3)
	DeepUi.title(passive_box, str(passive.get("name", "Passive")), 16, DeepUi.ACCENT_HI)
	DeepUi.wrap(passive_box, str(passive.get("text", "")), 13, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 380)
	## Their Birthstones, drawn again on their own when another of the three is read.
	var right := DeepUi.vbox(sides, 10)
	right.custom_minimum_size.x = BIRTH_WIDE
	home.region(right, "birthstone", func(holder: Control) -> void: _birth_card(home, holder, key, unlocked))
	var actions := DeepUi.hbox(box, 12)
	## The face they pull when the Birthstone fires sits at the foot of the page, beside the
	## buttons: the Birthstone's column is the tallest on the page and has no line to spare.
	## The face itself, not words for it (a line of stage directions read as a stray note).
	## A locked delver's would give their face away, so only an unlocked one shows it.
	if unlocked and Roster.Portrait.face(key, "birthstone") != null:
		var face := Roster.Portrait.new(key, Vector2(40, 40))
		face.mood = "birthstone"
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.tooltip_text = "The face %s pulls when %s fires" % [str(character.get("name", key)), str(stone.get("name", "the Birthstone"))]
		actions.add_child(face)
	DeepUi.spacer(actions)
	if not unlocked:
		var where: String = DeepProfile.lapidary_boss_mine(key)
		var sealed: bool = not where.is_empty() and not bool(home.profile.get("mines", {}).get(where, {}).get("unlocked", false))
		DeepUi.stat(actions, "lock", "%s.%s" % [Roster.unlock_hint(key), " That mine is still sealed." if sealed else ""], DeepUi.DIM, 13)
	elif chosen:
		DeepUi.pill(actions, "check", "Going down as %s" % str(character.get("name", key)), DeepUi.GOOD, 14)
		DeepUi.primary(actions, "gem", "Change their sockets", func() -> void: home.edit_loadout(key), 16)
	else:
		DeepUi.icon_button(actions, "gem", "Change their sockets", func() -> void: home.edit_loadout(key), 14, DeepUi.ACCENT).tooltip_text = "Changing their sockets also makes them the one going down."
		var picked_key: String = key
		DeepUi.primary(actions, "descend", "Go down as %s" % str(character.get("name", key)), func() -> void: home.choose_character(picked_key), 16)
	home.enter(card, 0.1)

static func _birth_card(home: Control, holder: Control, key: String, unlocked: bool) -> void:
	## The delver's three Birthstones as small stones, and the one of them being read: its
	## name, its words and its tiers, so a stone not bought yet is read before it is paid for.
	## At the card's foot, what is done with it: Wear, or Unlock and its second press
	## (HomeParts.birth_action). The card stands the height of the page whatever the ladder's
	## length, so that button never moves from stone to stone.
	var read: String = home.birth_read(key)
	var stone: Dictionary = DeepStone.birthstone(key, read)
	var tint: Color = HomeParts.birth_tone(stone)
	var birth_card := DeepUi.card(holder, Color(tint, 0.6), 14, Color(0.07, 0.06, 0.09, 0.92))
	birth_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var birth_box := DeepUi.vbox(birth_card, 6)
	var birth_head := DeepUi.hbox(birth_box, 14)
	HomeParts.birth_stones(home, birth_head, key, read, unlocked)
	var birth_names := DeepUi.vbox(birth_head, 0)
	birth_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(birth_names, "Birthstone", 11, DeepUi.DIM)
	DeepUi.title(birth_names, str(stone.get("name", "")), 22, HomeParts.birth_name_tone(stone))
	## Where it has been mastered: the mines whose final boss fell to them wearing it (K3). Under
	## its name, beside the stones, so the card stands no taller for it.
	if unlocked:
		var won: bool = not DeepProfile.stone_conquests(home.profile, key, read).is_empty()
		var mastered := DeepUi.label(birth_names, MineMap.mastered_in(home.profile, key, read) if won else "Mastered in: none yet", 11, DeepUi.ACCENT_HI if won else DeepUi.DIM)
		mastered.name = "MasteredIn"
		mastered.clip_text = true
		mastered.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		mastered.custom_minimum_size.x = 120
		mastered.mouse_filter = Control.MOUSE_FILTER_PASS
		mastered.tooltip_text = MineMap.mastered_in(home.profile, key, read) + "\nEvery delver and Birthstone has a diamond of its own on each mine's row of the Descend map, lit once its final boss falls to them."
	HomeParts.stone_words(birth_box, str(stone.get("text", "")), stone, 12, DeepUi.MUTED)
	HomeParts.birth_ladder(birth_box, stone)
	DeepUi.spacer(birth_box, false)
	HomeParts.birth_action(home, birth_box, key, read, unlocked)

# --- sockets --------------------------------------------------------------------------------------

static func _sockets_view(home: Control, content: VBoxContainer, character_key: String) -> void:
	## The rail of one unlocked delver. The sockets they have opened are filled from the vault:
	## drag a stone onto one, click a socket then a stone, or double-click a stone to set it in
	## the picked socket (or the first empty one it fits). A set stone dragged back to the vault
	## comes out. The next locked socket is for sale here, for good.
	var character: Dictionary = DeepContent.character(character_key)
	var record: Dictionary = home.profile.characters.get(character_key, {"rail": [], "dice": []})
	var sockets: Array = character.get("sockets", [])
	var rail_cap: int = DeepProfile.open_sockets(home.profile, character_key)
	if not DeepProfile.fillable_socket(home.profile, character_key, home._bench_socket) or home._bench_socket >= sockets.size():
		home._bench_socket = -1
	var filled: int = 0
	for index in range(rail_cap):
		if home.rail_skill(record, index) != "":
			filled += 1
	var rail_card := DeepUi.card(content, DeepUi.LINE, 16)
	var rail_box := DeepUi.vbox(rail_card, 10)
	var rail_head := DeepUi.hbox(rail_box, 8)
	DeepUi.section(rail_head, "gem", "Sockets").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var price: int = DeepEconomy.socket_price(home.profile, character_key)
	DeepUi.label(rail_head, "%d of %d set%s" % [filled, rail_cap, "" if price < 0 else "; locked sockets are filled in the mine until bought"], 13, DeepUi.GOOD if filled >= rail_cap else DeepUi.MUTED)
	DeepUi.gap(rail_head, 10)
	DeepUi.label(rail_head, "Drag a stone onto a socket, or click a socket then a stone." if home._bench_socket < 0 else "Choose a stone for socket %d." % (home._bench_socket + 1), 13, DeepUi.MUTED if home._bench_socket < 0 else DeepUi.ACCENT)
	var fill := DeepUi.icon_button(rail_head, "spark", "Fill empty sockets", func() -> void: fill_empty(home, character_key), 13, DeepUi.ACCENT)
	fill.tooltip_text = "Puts the best-graded stone that fits into each empty socket."
	fill.disabled = filled >= rail_cap or home.profile.get("vault", {}).is_empty()
	var rail_row := DeepUi.hbox(rail_box, 14)
	rail_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in range(sockets.size()):
		var skill: String = home.rail_skill(record, index)
		var stone: Dictionary = DeepProfile.owned(home.profile, skill) if DeepProfile.fillable_socket(home.profile, character_key, index) and skill != "" else {}
		home.enter(_socket_slot(home, rail_row, index, str(sockets[index]), stone, character_key), 0.05 + 0.04 * index)
	## An opal set where it cannot reach the gem beside or behind it says so (B2).
	RailWarnings.loadout(home, rail_row, character_key)
	## The Birthstone they wear, at the end of the rail: a click swaps it for another they own.
	var birth_tile := HomeParts.BirthstoneCard.new(rail_row, character_key, 150.0, false, DeepProfile.worn_birthstone(home.profile, character_key), true)
	home.enter(birth_tile, 0.05 + 0.04 * sockets.size())
	HomeParts.swap_tile(home, birth_tile, character_key)
	## Travelling light or heavy: what the count does to the luck of every stone found, why,
	## and how to lose it (S3), under the sockets it is counted from.
	var luck: Dictionary = DescendPage.luck_said(filled)
	if not luck.is_empty():
		var light := DeepUi.stat(rail_box, "gem", "%s · %s" % [str(luck.word), str(luck.why)], DeepUi.GOOD if DeepDescent.loadout_luck(filled) > 0.0 else DeepUi.BAD, 13, str(luck.tip))
		light.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		light.name = "LuckWhy"
	## The vault to set from, through the stone browser.
	var tray_card := DeepUi.card(content, DeepUi.LINE, 14)
	tray_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tray_box := DeepUi.vbox(tray_card, 8)
	var tray_head := DeepUi.hbox(tray_box, 8)
	var socket_color_now: String = str(sockets[home._bench_socket]) if home._bench_socket >= 0 else ""
	var suffix: String = ""
	if DeepContent.is_rainbow(socket_color_now):
		suffix = ": any stone fits a Rainbow socket"
	elif not socket_color_now.is_empty():
		suffix = ": stones a %s socket shows" % DeepContent.socket_name(socket_color_now)
	DeepUi.section(tray_head, "chest", "From the vault" + suffix).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StoneBrowser.toolbar(home, tray_head, "sockets", {"compact": true, "rarity": false})
	home.wire(tray_card, {}, Callable(), func(data: Dictionary) -> bool:
		return str(data.get("kind", "")) == "loadout_stone" and int(data.get("from_socket", -1)) >= 0,
		func(data: Dictionary) -> void:
			home.set_socket.call_deferred(character_key, int(data.from_socket), null, "ui_back"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.mouse_filter = Control.MOUSE_FILTER_PASS
	## Stones that fit the picked socket come first; the rest are dimmed after them.
	var stones: Array = pick_order(home, character_key, StoneBrowser.sorted(home, home.profile.get("vault", {}).values(), "sockets"))
	## A stone the Vault sent ("Socket it") goes first, on the first page.
	if not home._socket_ready.is_empty():
		for at in range(stones.size()):
			if str(stones[at].skill) == home._socket_ready:
				stones.push_front(stones.pop_at(at))
				break
	var pager_row := DeepUi.hbox(tray_box, 8)
	tray_box.add_child(flow)
	if home.profile.get("vault", {}).is_empty():
		DeepUi.label(flow, "The vault is empty.", 13, DeepUi.DIM)
	elif stones.is_empty():
		DeepUi.label(flow, "No kept stone matches.", 13, DeepUi.DIM)
	var against: Dictionary = DeepProfile.owned(home.profile, home.rail_skill(record, home._bench_socket)) if home._bench_socket >= 0 else {}
	for stone in home.paged(pager_row, "sockets_page", stones, PICK_PAGE):
		var chosen_key: String = str(stone.skill)
		var in_rail: bool = false
		for index in range(rail_cap):
			in_rail = in_rail or home.rail_skill(record, index) == chosen_key
		var fits: bool = pick_refusal(home, character_key, chosen_key).is_empty()
		var tile := StoneCard.tile(flow, stone, 70)
		tile.modulate = Color(1, 1, 1, 1.0 if fits else 0.3)
		tile.mouse_default_cursor_shape = Control.CURSOR_DRAG
		if in_rail:
			home.tile_mark(tile, "check", DeepUi.GOOD, "Already set")
		elif chosen_key == home._socket_ready:
			home.tile_mark(tile, "spark", DeepUi.ACCENT, ("From the vault: click it to set it in socket %d" % (home._bench_socket + 1)) if home._bench_socket >= 0 else "From the vault: double-click it to set it")
		mark_opal(home, tile, character_key, chosen_key)
		var shown_stone: Dictionary = stone
		tile.mouse_entered.connect(func() -> void: home.hover_stone(tile, shown_stone, against))
		dress_pick(home, tile, character_key, shown_stone, fits)
		home.wire(tile, {"kind": "loadout_stone", "skill": chosen_key, "from_socket": -1}, func() -> Control: return Thumbs.GemThumb.new(shown_stone, 64), Callable(), Callable())
		## A double-click sets it: in the picked socket, or the first empty one it fits.
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
				return
			if event.pressed and event.double_click:
				if Time.get_ticks_msec() - _set_at_msec < 700:
					return
				var target: int = home._bench_socket if home._bench_socket >= 0 and fits else _empty_fit(home, character_key, chosen_key)
				if target >= 0:
					home.set_socket(character_key, target, chosen_key, "dice_lock")
			elif not event.pressed and fits and home._bench_socket >= 0:
				_set_at_msec = Time.get_ticks_msec()
				home.set_socket(character_key, home._bench_socket, chosen_key, "dice_lock"))
		if fits and home._bench_socket >= 0:
			tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			DeepUi.juice(tile, 1.06)
	DeepUi.spacer(pager_row)
	DeepUi.label(pager_row, "Double-click a stone to set it · hold Shift to compare", 12, DeepUi.DIM)
	home.enter(tray_card, 0.1)

static func pick_order(home: Control, character_key: String, stones: Array) -> Array:
	## The picker's stones in the order to lay them out: those that fit the picked socket first,
	## the rest after them. The order is kept once laid out, so setting a stone (or putting the
	## socket down) leaves every other tile where it was; another socket or sort lays it out again.
	var key: String = "%s|%s" % [character_key, str(StoneBrowser.settings(home, "sockets"))]
	var socket: int = int(home._bench_socket)
	if str(_pick_order.get("key", "")) == key and (socket < 0 or socket == int(_pick_order.get("socket", -1))):
		var left: Dictionary = {}
		for stone in stones:
			left[str(stone.skill)] = stone
		var out: Array = []
		for skill in _pick_order.get("order", []):
			if left.has(skill):
				out.append(left[skill])
				left.erase(skill)
		for stone in stones:
			if left.has(str(stone.skill)):
				out.append(stone)
		return out
	if socket >= 0:
		var fits: Array = []
		var rest: Array = []
		for stone in stones:
			if DeepProfile.rail_refusal(home.profile, character_key, socket, str(stone.skill)).is_empty():
				fits.append(stone)
			else:
				rest.append(stone)
		stones = fits + rest
	_pick_order = {"key": key, "socket": socket, "order": stones.map(func(stone: Dictionary) -> String: return str(stone.skill))}
	return stones

static func pick_refusal(home: Control, character_key: String, skill: String) -> String:
	## Why the picker's stone cannot be set: in the picked socket, or with none picked, a second
	## opal (one opal a loadout, owner November 17, 2026). "" when it can.
	if home._bench_socket >= 0:
		return DeepProfile.rail_refusal(home.profile, character_key, home._bench_socket, skill)
	return DeepProfile.opal_refusal(home.profile, character_key, -1, skill)

static func mark_opal(home: Control, tile: PanelContainer, character_key: String, skill: String) -> void:
	## A lock on an opal the loadout will not take while another opal is set, saying why.
	var why: String = DeepProfile.opal_refusal(home.profile, character_key, int(home._bench_socket), skill)
	if not why.is_empty():
		home.tile_mark(tile, "lock", DeepUi.BAD, why.substr(0, 1).to_upper() + why.substr(1))

static func pick_target(home: Control, character_key: String, skill: String, fits: bool) -> int:
	## The socket a click (or the close look's Set) puts this stone in: the picked one if it
	## fits there, else the first empty one it fits; -1 for none.
	return int(home._bench_socket) if home._bench_socket >= 0 and fits else _empty_fit(home, character_key, skill)

static func dress_pick(home: Control, tile: Control, character_key: String, stone: Dictionary, fits: bool) -> void:
	## A picker tile's plate (the stone's own plate: what it does and when it fires) and its close
	## look's "Set in socket N". The plate is on the picture: hovered on a desk, held on a phone
	## (its card's Details is the close look). No comparison with the stone in the socket (K1
	## round 3, November 16, 2026: the owner found it cluttered).
	var thumb: Variant = tile.get_meta("thumb", null)
	if not thumb is Control:
		return
	var skill: String = str(stone.get("skill", ""))
	Tips.attach(thumb, func() -> Control: return pick_plate(home, character_key, stone, fits), {"tone": DeepUi.color(DeepStone.color(stone))})
	var target: int = pick_target(home, character_key, skill, fits)
	if target < 0 or not "inspect_opts" in thumb:
		return
	var record: Dictionary = home.profile.characters.get(character_key, {})
	if home.rail_skill(record, target) == skill:
		return
	thumb.inspect_opts = {"act": {"glyph": "gem", "label": "Set in socket %d" % (target + 1),
		"tip": "Sets it in socket %d of %s's loadout." % [target + 1, str(DeepContent.character(character_key).get("name", character_key))],
		"call": func() -> void: home.set_socket(character_key, target, skill, "dice_lock")}}

static func pick_plate(home: Control, character_key: String, stone: Dictionary, fits: bool) -> Control:
	## The picker's plate: the plain plate of the stone (its trigger, what it does, its weight),
	## and on a desk the footer saying what a click does.
	if not bool(stone.get("appraised", false)):
		return null
	var box: Control = Plates.gem(stone, {}, [], {}, [])
	## Why it cannot go (a second opal, another socket's color), on the plate in both layouts:
	## hovered on a desk, held on a phone.
	var why: String = pick_refusal(home, character_key, str(stone.get("skill", "")))
	if not why.is_empty():
		DeepUi.wrap(box, why.substr(0, 1).to_upper() + why.substr(1) + ".", 11, DeepUi.BAD).name = "PickRefusal"
		return box
	if not DeepUi.phone:
		var target: int = pick_target(home, character_key, str(stone.get("skill", "")), fits)
		var how: String = ("Click to set it in socket %d" % (target + 1)) if home._bench_socket >= 0 and fits else "Double-click to set"
		Plates.footer(box, how + " · Right-click · everything")
	return box

static func _empty_fit(home: Control, character_key: String, skill: String) -> int:
	## The first open, empty socket a stone fits, or -1.
	var record: Dictionary = home.profile.characters.get(character_key, {})
	var sockets: Array = DeepContent.character(character_key).get("sockets", [])
	for index in range(sockets.size()):
		if DeepProfile.fillable_socket(home.profile, character_key, index) and home.rail_skill(record, index).is_empty() and DeepProfile.rail_refusal(home.profile, character_key, index, skill).is_empty():
			return index
	return -1

static func fill_empty(home: Control, character_key: String) -> void:
	## Every empty open socket gets the best-graded stone that fits it and is not set already.
	var record: Dictionary = home.profile.characters.get(character_key, {})
	var sockets: Array = DeepContent.character(character_key).get("sockets", [])
	var best: Array = home.profile.get("vault", {}).values()
	best.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(DeepStone.grade(a).score) > int(DeepStone.grade(b).score))
	var changed: bool = false
	## Colored sockets first, so a stone that only fits one of them is not spent on an any-color one.
	var order: Array = range(sockets.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (not DeepContent.is_rainbow(str(sockets[a]))) and DeepContent.is_rainbow(str(sockets[b])))
	for index in order:
		if not DeepProfile.fillable_socket(home.profile, character_key, index) or not home.rail_skill(record, index).is_empty():
			continue
		for stone in best:
			var skill: String = str(stone.get("skill", ""))
			if record.get("rail", []).has(skill):
				continue
			if DeepProfile.set_rail(home.profile, character_key, index, skill).is_empty():
				changed = true
				break
	if changed:
		DeepAudio.play("dice_lock", {"volume": 0.8})
		home._bench_socket = -1
		home.profile_changed.emit()

static func _socket_slot(home: Control, parent: Node, index: int, socket_color: String, stone: Dictionary, character_key: String) -> PanelContainer:
	## One socket of the loadout, as a card to click, drag from and drop on; or, past the
	## sockets the delver has opened, a locked one, the next of them with its price.
	var locked: bool = not DeepProfile.fillable_socket(home.profile, character_key, index)
	var chosen: bool = index == home._bench_socket
	var tone: Color = DeepUi.socket_tone(socket_color, DeepUi.LINE_HI)
	var border: Color = DeepUi.LINE if locked else (DeepUi.ACCENT if chosen else Color(tone, 0.45))
	var card := DeepUi.card(parent, border, 10, Color(0.04, 0.045, 0.06, 0.8) if locked else Color(0.05, 0.06, 0.085, 0.9))
	card.custom_minimum_size = Vector2(150, 0)
	var box := DeepUi.vbox(card, 6)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	var ring := BattleScreen.SocketRing.new(socket_color, stone.is_empty())
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	## At home a stone is only ever set where the socket shows it, so a set socket is lit.
	if not stone.is_empty():
		ring.shown = 1
	if locked:
		card.tooltip_text = home.MINE_SOCKET
		ring.modulate = Color(1, 1, 1, 0.45)
		var lock := DeepUi.icon(slot, "lock", 30, DeepUi.MUTED, home.MINE_SOCKET)
		lock.position = Vector2(23, 23)
		DeepUi.label(box, DeepContent.socket_name(socket_color), 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if index == DeepProfile.open_sockets(home.profile, character_key):
			var price: int = DeepEconomy.socket_price(home.profile, character_key)
			var buy := DeepUi.priced(DeepUi.icon_button(box, "lock_open", "", func() -> void: home.buy_socket(character_key), 13, DeepUi.GOOD), str(price))
			buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			buy.disabled = int(home.profile.get("gold", 0)) < price
			buy.tooltip_text = ("Open this socket for good: it is filled from the vault before every run, in every mine." if not buy.disabled
				else "You have %d gold. This socket costs %d." % [int(home.profile.get("gold", 0)), price])
			DeepUi.voice(buy, "buy")
			## A locked socket says nothing of luck (owner, November 17, 2026): only the stones
			## set in open sockets count (DescendPage.loaded), so it has none to cost.
		else:
			DeepUi.label(box, "open socket %d first" % (DeepProfile.open_sockets(home.profile, character_key) + 1), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return card
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if chosen:
		ring.set_ready(true)
	var socket_index: int = index
	var data: Dictionary = {}
	if not stone.is_empty():
		var thumb := StoneCard.mini(slot, stone, 60, DeepStone.name(stone))
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", "")), 14, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		var trigger_row := DeepUi.hbox(box, 0)
		trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
		## When it fires, the only such line under the stone: light, at the text floor.
		DiceIcons.build(trigger_row, DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(DeepStone.effective(stone, {}).cut_step)), 22, DeepUi.PAPER.darkened(0.12))
		var remove := DeepUi.icon_button(slot, "cross_out", "", func() -> void: home.set_socket(character_key, socket_index, null, ""), 10, DeepUi.MUTED)
		DeepUi.voice(remove, "ui_back")
		remove.tooltip_text = "Take the stone out"
		remove.position = Vector2(66, -6)
		data = {"kind": "loadout_stone", "skill": str(stone.get("skill", "")), "from_socket": index}
	else:
		DeepUi.label(box, DeepContent.socket_name(socket_color), 13, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, "empty", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	DeepUi.juice(card, 1.04)
	var here: String = str(stone.get("skill", ""))
	home.wire(card, data, func() -> Control: return Thumbs.GemThumb.new(stone, 64),
		func(incoming: Dictionary) -> bool:
			var skill: String = str(incoming.get("skill", ""))
			return str(incoming.get("kind", "")) == "loadout_stone" and skill != here and DeepProfile.rail_refusal(home.profile, character_key, socket_index, skill).is_empty(),
		func(incoming: Dictionary) -> void:
			home.set_socket.call_deferred(character_key, socket_index, str(incoming.skill), "dice_lock"),
		ring)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			home._bench_socket = -1 if home._bench_socket == socket_index else socket_index
			DeepAudio.play("ui_tap")
			home._render.call_deferred())
	return card
