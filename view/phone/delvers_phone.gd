extends RefCounted
## Delvers on the phone (docs/PHONE_UI.md, board home-delvers, approved November 7, 2026).
## A delver: six cards in a row on top, the one looked at below in three columns (who they are
## and Change their sockets; their dice, sockets and passive; their Birthstone's tiers, every
## tier's words starting on one line, the owner's note). Their sockets: seven tiles in a row,
## and the vault's stones under them in a grid that scrolls. Tap a socket, then a stone.

const DelversPage = preload("res://view/home/delvers_page.gd")
const Roster = preload("res://view/home/roster.gd")
const StoneBrowser = preload("res://view/home/stone_browser.gd")
const StoneCard = preload("res://view/gems/stone_card.gd")
const HomeParts = preload("res://view/home/home_parts.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")
const Thumbs = preload("res://view/gems/thumbs.gd")
const GemMesh = preload("res://view/gems/gem_mesh.gd")
const BattleScreen = preload("res://view/battle/battle_screen.gd")
const Tips = preload("res://view/ui/tips.gd")

static func build(home: Control, content: VBoxContainer) -> void:
	var current: String = str(home.profile.get("current_character", DeepContent.starter_character()))
	if home._roster_pick.is_empty() or DeepContent.character(home._roster_pick).is_empty():
		home._roster_pick = current
	var unlocked: Array = DeepProfile.unlocked_characters(home.profile)
	if not unlocked.has(home._roster_pick):
		home._roster_view = "dossier"
	if home._roster_view == "sockets":
		_sockets(home, content, home._roster_pick)
		return
	_strip(home, content, current)
	_dossier(home, content, home._roster_pick, unlocked.has(home._roster_pick), home._roster_pick == current)

static func _panel(parent: Node, edge: Color, pad: float = 7.0) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", DeepUi.ledger(DeepUi.LEDGER_FILL, edge, 10, int(DeepUi.pt(pad)), int(DeepUi.pt(1.5)), 4))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(card)
	return DeepUi.vbox(card, int(DeepUi.pt(4)))

static func _strip(home: Control, content: VBoxContainer, current: String) -> void:
	## Six cards, 104 by 70 points: the face, the name and the title (or a lock); the one looked
	## at outlined in gold, the one going down ticked.
	var row := DeepUi.hbox(content, int(DeepUi.pt(6)))
	for key in DeepContent.characters_in_unlock_order():
		var record: Dictionary = home.profile.get("characters", {}).get(str(key), {})
		var open: bool = bool(record.get("unlocked", false))
		var looked: bool = str(key) == home._roster_pick
		var character: Dictionary = DeepContent.character(str(key))
		var tile := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("211d14") if looked else Color("141826")
		style.border_color = DeepUi.ACCENT if looked else DeepUi.LINE
		style.set_border_width_all(int(DeepUi.pt(1.5)) if looked else int(DeepUi.pt(1)))
		style.set_corner_radius_all(int(DeepUi.pt(6)))
		style.content_margin_top = DeepUi.pt(4)
		style.content_margin_bottom = DeepUi.pt(4)
		tile.add_theme_stylebox_override("panel", style)
		tile.custom_minimum_size = Vector2(0, DeepUi.pt(68))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.tooltip_text = str(character.get("text", "")) if open else "Locked. " + Roster.unlock_hint(str(key)) + "."
		row.add_child(tile)
		var column := DeepUi.vbox(tile, 0)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := Roster.Portrait.new(str(key), Vector2(DeepUi.pt(30), DeepUi.pt(30)), not open, false, false)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(face)
		var named := DeepUi.label(column, str(character.get("name", key)), 12, DeepUi.ACCENT_HI if looked else (DeepUi.PAPER if open else DeepUi.DIM), HORIZONTAL_ALIGNMENT_CENTER)
		named.add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.label(column, str(character.get("title", "")) if open else "locked", 11, DeepUi.MUTED if open else DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		if str(key) == current:
			var tick := DeepUi.icon(tile, "check", DeepUi.pt(11), DeepUi.GOOD, "Going down")
			tick.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		if bool(record.get("fresh", false)):
			HomeParts.pin(tile, 0, home.PIP_NEW, true)
		var picked: String = str(key)
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				DeepAudio.play("ui_tap")
				home._roster_pick = picked
				home._bench_socket = -1
				if home.profile.get("characters", {}).has(picked) and bool(home.profile.characters[picked].get("fresh", false)):
					home.profile.characters[picked].erase("fresh")
					home.touch()
				home._render())

static func _dossier(home: Control, content: VBoxContainer, key: String, unlocked: bool, chosen: bool) -> void:
	var character: Dictionary = DeepContent.character(key)
	var passive: Dictionary = character.get("passive", {})
	var stone: Dictionary = DeepStone.birthstone(key)
	var tint: Color = GemMesh.tint(stone) if not stone.is_empty() else DeepUi.ACCENT
	var columns := DeepUi.hbox(content, int(DeepUi.pt(10)))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## Who they are, and what to do with them.
	var left := DeepUi.vbox(columns, int(DeepUi.pt(5)))
	left.custom_minimum_size.x = DeepUi.pt(178)
	var head := DeepUi.hbox(left, int(DeepUi.pt(8)))
	var face := Roster.Portrait.new(key, Vector2(DeepUi.pt(56), DeepUi.pt(56)), not unlocked, false, chosen)
	head.add_child(face)
	var names := DeepUi.vbox(head, -4)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DeepUi.title(names, str(character.get("name", key)), 20, DeepUi.PAPER if unlocked else DeepUi.DIM)
	DeepUi.label(names, str(character.get("title", "")), 12, DeepUi.MUTED)
	DeepUi.wrap(left, str(character.get("text", "")), 12, DeepUi.MUTED)
	if not unlocked:
		DeepUi.pill(left, "lock", Roster.unlock_hint(key), DeepUi.DIM, 11)
	elif chosen:
		DeepUi.pill(left, "check", "Going down", DeepUi.GOOD, 11)
	DeepUi.spacer(left, false)
	if unlocked:
		var change := DeepUi.primary(left, "gem", "Change their sockets", func() -> void: home.edit_loadout(key), 13)
		change.custom_minimum_size.y = DeepUi.pt(40)
		if not chosen:
			var picked: String = key
			var go := DeepUi.icon_button(left, "descend", "Go down as %s" % str(character.get("name", key)), func() -> void: home.choose_character(picked), 13, DeepUi.ACCENT)
			DeepUi.ledger_button(go, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 9)
			go.custom_minimum_size.y = DeepUi.pt(40)
	## Their kit: health and sockets, dice, sockets, passive.
	var middle := DeepUi.vbox(columns, int(DeepUi.pt(5)))
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pills := DeepUi.hbox(middle, int(DeepUi.pt(4)))
	DeepUi.pill(pills, "heart", "%d health" % int(character.get("hp", 0)), DeepUi.HP, 11)
	DeepUi.pill(pills, "gem", DeepUi.plural(character.get("sockets", []).size(), "socket"), DeepUi.INFO, 11)
	DeepUi.section(middle, "die", "Their dice", DeepUi.ACCENT, 11)
	var dice_row := DeepUi.hbox(middle, int(DeepUi.pt(8)))
	dice_row.tooltip_text = home.OWN_DICE
	var die_index: int = 0
	for die_key in character.get("dice", []):
		var die: Dictionary = DeepForge.die_from(die_key, "roster_%s_%d" % [key, die_index])
		var holder := DeepUi.vbox(dice_row, 0)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		var thumb := Thumbs.DieThumb.new(die, DeepUi.pt(30))
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.add_child(thumb)
		DeepUi.label(holder, DeepDice.describe(die), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		die_index += 1
	DeepUi.section(middle, "gem", "Their sockets", DeepUi.ACCENT, 11)
	var socket_row := DeepUi.hbox(middle, int(DeepUi.pt(4)))
	var open_socket: Callable = func(index: int) -> void: home.edit_loadout(key, index)
	home.socket_strip(socket_row, key, DeepProfile.loadout(home.profile, key), DeepUi.pt(28), false, open_socket if unlocked else Callable())
	var passive_box := _panel(middle, Color(DeepUi.ACCENT, 0.45), 6)
	var passive_head := DeepUi.label(passive_box, str(passive.get("name", "Passive")), 12, DeepUi.ACCENT_HI)
	passive_head.add_theme_font_override("font", DeepUi.bold_font())
	DeepUi.wrap(passive_box, str(passive.get("text", "")), 12, DeepUi.PAPER)
	## Their Birthstone: its name, and its tiers as one ladder, the words of every tier starting
	## on the same line (a column for the marks as wide as the widest of them).
	var right := _panel(columns, Color(tint, 0.7), 7)
	right.get_parent().custom_minimum_size.x = DeepUi.pt(224)
	var birth_head := DeepUi.hbox(right, int(DeepUi.pt(6)))
	if not stone.is_empty():
		StoneCard.mini(birth_head, stone, DeepUi.pt(30), str(stone.get("name", "")))
	var birth_names := DeepUi.vbox(birth_head, -4)
	birth_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DeepUi.label(birth_names, "Birthstone", 11, DeepUi.DIM)
	DeepUi.title(birth_names, str(stone.get("name", "")), 17, tint.lightened(0.35))
	var tiers: Array = stone.get("tiers", [])
	var die: String = DiceIcons.ladder_die(tiers)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(DeepUi.pt(6)))
	grid.add_theme_constant_override("v_separation", int(DeepUi.pt(5)))
	right.add_child(grid)
	for tier in tiers:
		var mark := HBoxContainer.new()
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mark.custom_minimum_size.x = DeepUi.pt(44)
		grid.add_child(mark)
		if DiceIcons.ladder_rung(tier, die) > 0:
			DiceIcons.build_ladder(mark, [tier], die, DiceIcons.ladder_rung(tier, die), DeepUi.pt(8), DeepUi.MUTED, DeepUi.DIM)
		else:
			DiceIcons.build(mark, DeepPatterns.describe(tier.get("trigger", {"kind": "always"}), 0), DeepUi.pt(10), DeepUi.MUTED, str(tier.get("text", "")))
		var words := DeepUi.vbox(grid, -2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var named := DeepUi.label(words, str(tier.get("name", "")), 12, DeepUi.PAPER)
		named.add_theme_font_override("font", DeepUi.bold_font())
		DeepUi.wrap(words, str(tier.get("text", "")), 11, DeepUi.MUTED)

# --- their sockets -----------------------------------------------------------------------------------

static func _sockets(home: Control, content: VBoxContainer, character_key: String) -> void:
	## One row: back, the delver (step through with the arrows), Going down. Then the sockets as
	## seven tiles, and the vault's stones in a grid that scrolls. Tap a socket, then a stone;
	## dragging still works.
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
	var head := DeepUi.hbox(content, int(DeepUi.pt(8)))
	var back := DeepUi.icon_button(head, "prev", "Delvers", func() -> void:
		home._roster_view = "dossier"
		home._bench_socket = -1
		home._render(), 12, DeepUi.MUTED)
	DeepUi.ledger_button(back, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 6)
	back.custom_minimum_size.y = DeepUi.pt(32)
	DeepUi.spacer(head)
	var owned: Array = DeepProfile.unlocked_characters(home.profile)
	var previous := DeepUi.icon_button(head, "prev", "", func() -> void: home.step_character(-1), 12, DeepUi.MUTED)
	previous.disabled = owned.size() < 2
	previous.custom_minimum_size = Vector2(DeepUi.pt(36), DeepUi.pt(32))
	head.add_child(Roster.Portrait.new(character_key, Vector2(DeepUi.pt(26), DeepUi.pt(26)), false, false, true))
	var named := DeepUi.label(head, DeepContent.character_title(character_key), 14, DeepUi.PAPER)
	named.add_theme_font_override("font", DeepUi.bold_font())
	var next := DeepUi.icon_button(head, "next", "", func() -> void: home.step_character(1), 12, DeepUi.MUTED)
	next.disabled = owned.size() < 2
	next.custom_minimum_size = Vector2(DeepUi.pt(36), DeepUi.pt(32))
	DeepUi.spacer(head)
	DeepUi.pill(head, "check", "Going down", DeepUi.GOOD, 11)
	var rail_row := DeepUi.hbox(content, int(DeepUi.pt(6)))
	for index in range(sockets.size()):
		var skill: String = home.rail_skill(record, index)
		var stone: Dictionary = DeepProfile.owned(home.profile, skill) if DeepProfile.fillable_socket(home.profile, character_key, index) and skill != "" else {}
		_socket_tile(home, rail_row, index, str(sockets[index]), stone, character_key)
	_birth_tile(rail_row, character_key)
	## The line under the sockets, and the browser's controls on the same row.
	var bar := DeepUi.hbox(content, int(DeepUi.pt(6)))
	var luck: float = DeepDescent.loadout_luck(filled)
	DeepUi.label(bar, "%d of %d set" % [filled, rail_cap], 11, DeepUi.GOOD if filled >= rail_cap else DeepUi.MUTED)
	if luck != 0.0:
		DeepUi.label(bar, "%+d luck" % int(luck), 11, DeepUi.GOOD if luck > 0.0 else DeepUi.BAD)
	DeepUi.label(bar, "· tap a socket, then a stone" if home._bench_socket < 0 else "· choose a stone for socket %d" % (home._bench_socket + 1), 11, DeepUi.MUTED if home._bench_socket < 0 else DeepUi.ACCENT)
	DeepUi.spacer(bar)
	var tools := StoneBrowser.toolbar_phone(home, bar, "sockets")
	tools.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := DeepUi.icon_button(bar, "spark", "Fill", func() -> void: DelversPage.fill_empty(home, character_key), 11, DeepUi.ACCENT)
	DeepUi.ledger_button(fill, DeepUi.SLATE_HI, DeepUi.LEDGER_LINE, 6)
	fill.custom_minimum_size.y = DeepUi.pt(30)
	fill.tooltip_text = "Puts the best-graded stone that fits into each empty socket."
	fill.disabled = filled >= rail_cap or home.profile.get("vault", {}).is_empty()
	## The vault's stones, nine a row, scrolling.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_meta("may_scroll", true)
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", int(DeepUi.pt(5)))
	grid.add_theme_constant_override("v_separation", int(DeepUi.pt(5)))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	home.wire(scroll, {}, Callable(), func(data: Dictionary) -> bool:
		return str(data.get("kind", "")) == "loadout_stone" and int(data.get("from_socket", -1)) >= 0,
		func(data: Dictionary) -> void:
			home.set_socket.call_deferred(character_key, int(data.from_socket), null, "ui_back"))
	var stones: Array = StoneBrowser.sorted(home, home.profile.get("vault", {}).values(), "sockets")
	if home._bench_socket >= 0:
		var fits: Array = []
		var rest: Array = []
		for s in stones:
			if DeepProfile.rail_refusal(home.profile, character_key, home._bench_socket, str(s.skill)).is_empty():
				fits.append(s)
			else:
				rest.append(s)
		stones = fits + rest
	if not home._socket_ready.is_empty():
		for at in range(stones.size()):
			if str(stones[at].skill) == home._socket_ready:
				stones.push_front(stones.pop_at(at))
				break
	if stones.is_empty():
		DeepUi.label(grid, "The vault is empty." if home.profile.get("vault", {}).is_empty() else "No kept stone matches.", 13, DeepUi.DIM)
	for stone in stones:
		var chosen_key: String = str(stone.skill)
		var in_rail: bool = false
		for index in range(rail_cap):
			in_rail = in_rail or home.rail_skill(record, index) == chosen_key
		var fits: bool = home._bench_socket < 0 or DeepProfile.rail_refusal(home.profile, character_key, home._bench_socket, chosen_key).is_empty()
		var tile := StoneCard.tile(grid, stone, DeepUi.pt(44))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.modulate = Color(1, 1, 1, 1.0 if fits else 0.3)
		if in_rail:
			home.tile_mark(tile, "check", DeepUi.GOOD, "Already set")
		var shown_stone: Dictionary = stone
		home.wire(tile, {"kind": "loadout_stone", "skill": chosen_key, "from_socket": -1}, func() -> Control: return Thumbs.GemThumb.new(shown_stone, DeepUi.pt(40)), Callable(), Callable())
		## A tap sets it: in the picked socket, or, with none picked, the first empty one it fits.
		tile.gui_input.connect(func(event: InputEvent) -> void:
			if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or event.pressed or Tips.held(tile):
				return
			var target: int = home._bench_socket if home._bench_socket >= 0 and fits else DelversPage._empty_fit(home, character_key, chosen_key)
			if target >= 0:
				home.set_socket(character_key, target, chosen_key, "dice_lock"))

static func _socket_tile(home: Control, parent: Node, index: int, socket_color: String, stone: Dictionary, character_key: String) -> void:
	## One socket: its ring, the stone's name and trigger; tapped, it is the socket the next
	## stone goes in. A set stone has an × to take it out. Past the open ones, a lock, the next
	## with its price.
	var locked: bool = not DeepProfile.fillable_socket(home.profile, character_key, index)
	var chosen: bool = index == home._bench_socket
	var tone: Color = DeepUi.socket_tone(socket_color, DeepUi.LINE_HI)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211d14") if chosen else Color("141826")
	style.border_color = DeepUi.ACCENT if chosen else (DeepUi.LINE if locked else Color(tone, 0.6))
	style.set_border_width_all(int(DeepUi.pt(1.5)))
	style.set_corner_radius_all(int(DeepUi.pt(6)))
	style.content_margin_top = DeepUi.pt(4)
	style.content_margin_bottom = DeepUi.pt(4)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(DeepUi.pt(84), DeepUi.pt(92))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(card)
	var box := DeepUi.vbox(card, int(DeepUi.pt(2)))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(DeepUi.pt(44), DeepUi.pt(44))
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	var ring := BattleScreen.SocketRing.new(socket_color, stone.is_empty())
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	if not stone.is_empty():
		ring.shown = 1
	if locked:
		card.tooltip_text = home.MINE_SOCKET
		ring.modulate = Color(1, 1, 1, 0.45)
		var lock := DeepUi.icon(slot, "lock", DeepUi.pt(16), DeepUi.MUTED)
		lock.position = Vector2.ONE * DeepUi.pt(14)
		DeepUi.label(box, DeepContent.socket_name(socket_color), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		if index == DeepProfile.open_sockets(home.profile, character_key):
			var price: int = DeepEconomy.socket_price(home.profile, character_key)
			var buy := DeepUi.priced(DeepUi.icon_button(box, "lock_open", "", func() -> void: home.buy_socket(character_key), 11, DeepUi.GOOD), str(price))
			buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			buy.custom_minimum_size.y = DeepUi.pt(DeepUi.FINGER_LEAST)
			buy.disabled = int(home.profile.get("gold", 0)) < price
			DeepUi.voice(buy, "buy")
		else:
			DeepUi.label(box, "open %d first" % (DeepProfile.open_sockets(home.profile, character_key) + 1), 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		return
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if chosen:
		ring.set_ready(true)
	var socket_index: int = index
	var data: Dictionary = {}
	if not stone.is_empty():
		var thumb := StoneCard.mini(slot, stone, DeepUi.pt(34), DeepStone.name(stone))
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(DeepUi.pt(5)))
		thumb.mouse_filter = Control.MOUSE_FILTER_PASS
		var said := DeepUi.label(box, str(DeepStone.skill_of(stone).get("name", "")), 12, DeepUi.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		said.add_theme_font_override("font", DeepUi.bold_font())
		var trigger_row := DeepUi.hbox(box, 0)
		trigger_row.alignment = BoxContainer.ALIGNMENT_CENTER
		DiceIcons.build(trigger_row, DeepPatterns.describe(DeepStone.skill_of(stone).get("trigger", {"kind": "always"}), int(DeepStone.effective(stone, {}).cut_step)), DeepUi.pt(11), DeepUi.MUTED)
		## The × over the card's top right corner, in a layer of its own: a panel stretches
		## whatever is put in it straight.
		var over := Control.new()
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(over)
		var remove := DeepUi.icon_button(over, "cross_out", "", func() -> void: home.set_socket(character_key, socket_index, null, ""), 10, DeepUi.MUTED)
		DeepUi.voice(remove, "ui_back")
		remove.tooltip_text = "Take the stone out"
		remove.flat = true
		remove.custom_minimum_size = Vector2(DeepUi.pt(DeepUi.FINGER_LEAST), DeepUi.pt(DeepUi.FINGER_LEAST))
		remove.size = remove.custom_minimum_size
		remove.anchor_left = 1.0
		remove.anchor_right = 1.0
		remove.offset_left = -DeepUi.pt(26)
		remove.offset_right = 0.0
		remove.offset_top = -DeepUi.pt(4)
		remove.offset_bottom = DeepUi.pt(22)
		data = {"kind": "loadout_stone", "skill": str(stone.get("skill", "")), "from_socket": index}
	else:
		DeepUi.label(box, DeepContent.socket_name(socket_color), 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		DeepUi.label(box, "empty", 11, DeepUi.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var here: String = str(stone.get("skill", ""))
	home.wire(card, data, func() -> Control: return Thumbs.GemThumb.new(stone, DeepUi.pt(40)),
		func(incoming: Dictionary) -> bool:
			var skill: String = str(incoming.get("skill", ""))
			return str(incoming.get("kind", "")) == "loadout_stone" and skill != here and DeepProfile.rail_refusal(home.profile, character_key, socket_index, skill).is_empty(),
		func(incoming: Dictionary) -> void:
			home.set_socket.call_deferred(character_key, socket_index, str(incoming.skill), "dice_lock"),
		ring)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not Tips.held(card):
			home._bench_socket = -1 if home._bench_socket == socket_index else socket_index
			DeepAudio.play("ui_tap")
			home._render.call_deferred())

static func _birth_tile(parent: Node, character_key: String) -> void:
	## The Birthstone at the end of the row: always set, nothing to tap.
	var stone: Dictionary = DeepStone.birthstone(character_key)
	if stone.is_empty():
		return
	var tint: Color = GemMesh.tint(stone)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a1420")
	style.border_color = Color(tint, 0.8)
	style.set_border_width_all(int(DeepUi.pt(1.5)))
	style.set_corner_radius_all(int(DeepUi.pt(6)))
	style.content_margin_top = DeepUi.pt(4)
	style.content_margin_bottom = DeepUi.pt(4)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(DeepUi.pt(84), DeepUi.pt(92))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(card)
	var box := DeepUi.vbox(card, int(DeepUi.pt(2)))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(DeepUi.pt(44), DeepUi.pt(44))
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	var ring := BattleScreen.SocketRing.new("BIRTHSTONE", false)
	ring.birth_tint = tint
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(ring)
	var thumb := StoneCard.mini(slot, stone, DeepUi.pt(34), str(stone.get("name", "")) + "\n" + str(stone.get("text", "")))
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(DeepUi.pt(5)))
	var said := DeepUi.label(box, str(stone.get("name", "")), 12, tint.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
	said.add_theme_font_override("font", DeepUi.bold_font())
	DeepUi.label(box, "always set", 11, DeepUi.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
