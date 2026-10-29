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

## How many vault stones the socket picker shows a page: three rows.
const PICK_PAGE: int = 42
## When a click set a stone in the picked socket: the grid is drawn again at once, so the
## second press of a double-click lands on whatever tile now stands under the pointer, and
## must not set that one as well.
static var _set_at_msec: int = -100000

static func build(home: Control, content: VBoxContainer) -> void:
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
	var back := DeepUi.icon_button(left_slot, "prev", "Delvers", func() -> void:
		home._roster_view = "dossier"
		home._bench_socket = -1
		home._render(), 14, DeepUi.MUTED)
	back.tooltip_text = "Back to the delvers (Esc)"
	DeepUi.voice(back, "ui_back")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	var stone: Dictionary = DeepStone.birthstone(key)
	var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var card := DeepUi.card(content, Color(tint if unlocked else DeepUi.LINE, 0.5), 18)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := DeepUi.vbox(card, 14)
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
	var right := DeepUi.vbox(columns, 10)
	right.custom_minimum_size.x = 420
	var birth_card := DeepUi.card(right, Color(tint, 0.6), 14, Color(0.07, 0.06, 0.09, 0.92))
	var birth_box := DeepUi.vbox(birth_card, 3)
	var birth_head := DeepUi.hbox(birth_box, 12)
	if not stone.is_empty():
		var picture := StoneCard.mini(birth_head, stone, 84, str(stone.get("name", "")) + "\n" + str(stone.get("text", "")))
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var birth_names := DeepUi.vbox(birth_head, 2)
	birth_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(birth_names, "Birthstone", 11, DeepUi.DIM)
	DeepUi.title(birth_names, str(stone.get("name", "")), 22, tint.lightened(0.35))
	DeepUi.wrap(birth_names, str(stone.get("text", "")), 12, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 290)
	var die: String = DiceIcons.ladder_die(stone.get("tiers", []))
	for tier in stone.get("tiers", []):
		var tier_row := DeepUi.hbox(birth_box, 10)
		tier_row.mouse_filter = Control.MOUSE_FILTER_PASS
		var mark := DeepUi.center(tier_row)
		## Marks at 20 with their words at the text floor ("d4/d12 ×5" was 9 px at 14).
		mark.custom_minimum_size.x = 92 if die.is_empty() else 100
		if DiceIcons.ladder_rung(tier, die) > 0:
			DiceIcons.build_ladder(mark, [tier], die, DiceIcons.ladder_rung(tier, die), 20, DeepUi.MUTED, DeepUi.DIM)
		else:
			DiceIcons.build(mark, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), 20, DeepUi.MUTED, str(tier.get("text", "")))
		var words := DeepUi.vbox(tier_row, 1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DeepUi.label(words, str(tier.get("name", "")), 13, DeepUi.PAPER)
		DeepUi.wrap(words, str(tier.get("text", "")), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 300)
	var actions := DeepUi.hbox(box, 12)
	## The face they pull when the Birthstone fires sits at the foot of the card, beside the
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
	## Travelling light or heavy: what the count does to the luck of every stone found.
	var luck: float = DeepDescent.loadout_luck(filled)
	if luck != 0.0:
		var light := DeepUi.label(rail_head, "travelling %s: %+d luck on every stone found" % ["light" if luck > 0.0 else "heavy", int(luck)], 13, DeepUi.GOOD if luck > 0.0 else DeepUi.BAD)
		light.tooltip_text = "Three stones is the mine as it is. Every socket left empty adds %d luck to every stone the mine gives you; every stone over three takes %d off." % [int(DeepContent.constant("loadout_luck_per_stone", 2)), int(DeepContent.constant("loadout_luck_per_stone", 2))]
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
	home.enter(HomeParts.BirthstoneCard.new(rail_row, character_key), 0.05 + 0.04 * sockets.size())
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
	var stones: Array = StoneBrowser.sorted(home, home.profile.get("vault", {}).values(), "sockets")
	## Stones that fit the picked socket come first; the rest are dimmed after them.
	if home._bench_socket >= 0:
		var fits: Array = []
		var rest: Array = []
		for s in stones:
			if DeepProfile.rail_refusal(home.profile, character_key, home._bench_socket, str(s.skill)).is_empty():
				fits.append(s)
			else:
				rest.append(s)
		stones = fits + rest
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
		var fits: bool = home._bench_socket < 0 or DeepProfile.rail_refusal(home.profile, character_key, home._bench_socket, chosen_key).is_empty()
		var tile := StoneCard.tile(flow, stone, 70)
		tile.modulate = Color(1, 1, 1, 1.0 if fits else 0.3)
		tile.mouse_default_cursor_shape = Control.CURSOR_DRAG
		if in_rail:
			home.tile_mark(tile, "check", DeepUi.GOOD, "Already set")
		elif chosen_key == home._socket_ready:
			home.tile_mark(tile, "spark", DeepUi.ACCENT, ("From the vault: click it to set it in socket %d" % (home._bench_socket + 1)) if home._bench_socket >= 0 else "From the vault: double-click it to set it")
		var shown_stone: Dictionary = stone
		tile.mouse_entered.connect(func() -> void: home.hover_stone(tile, shown_stone, against))
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
