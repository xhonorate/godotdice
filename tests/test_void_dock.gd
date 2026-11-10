extends SceneTree
## The Void's marks on the fight's dock (view/battle/void_marks.gd; the owner's review of
## November 9, 2026): riders as icon moons with a "+N" count, the first rider of an empty socket
## straight in the socket's ring, the popout that lays a socket's riders out in runs and pages,
## the figure beside the name (alone when it is too long), the play counter, the float row of
## phantom dice and its stacks and fold, on the desktop and on the phone.

var failures: Array = []
var checks: int = 0
var viewport: SubViewport

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	root.add_child(viewport)
	_numbers()
	await _desk()
	await _phone()
	viewport.free()
	print("Void dock: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

# --- fixtures ------------------------------------------------------------------------------------

func gem(key: String, id: String, fragile: bool = true) -> Dictionary:
	var stone: Dictionary = DeepStone.make(key, 6, 4, 2 if fragile else 3, ["VOID"] if fragile else [], {}, id)
	stone.appraised = true
	stone.inclusions_revealed = true
	return stone

func fight(riders: Array, copies_on: int = -1, copies: int = 0) -> Dictionary:
	## A fight with riders on the sockets (`riders[socket]` a list of skill keys), and, if asked,
	## an Echo's run of copies of one gem on one socket.
	var bowl: Array = []
	for j in range(5):
		bowl.append(DeepDice.make("D6", "p_d%d" % j))
	var rail: Array = [gem("STRIKE", "p_s0", false), gem("GUARD", "p_s1", false), gem("MEND", "p_s2", false), null]
	var lines: Array = []
	for socket in range(rail.size()):
		var line: Array = []
		if socket < riders.size():
			for key in riders[socket]:
				line.append(gem(str(key), "p_%s_%d" % [str(key).to_lower(), socket]))
		if socket == copies_on:
			for k in range(copies):
				var copy: Dictionary = gem("VENOM", "p_venom-void%d" % k)
				line.append(copy)
		lines.append(line)
	var unit: Dictionary = DeepBattle.make_player("p", "Player", "ARDOR", rail, bowl, -1, lines)
	unit.birthstone = {}
	unit.passive = {}
	unit.hp = 1000
	unit.max_hp = 1000
	var rng: Dictionary = DeepRng.streams(17, ["dice", "creatures"])
	var state: Dictionary = DeepBattle.begin([unit], ["CAVE_TICK"], {"depth": 1}, rng.dice, rng.creatures)
	for foe in state.enemies:
		foe.max_hp = 2000
		foe.hp = 2000
	return {"state": state, "rng": rng}

func screen_for(f: Dictionary) -> Control:
	var battle: Control = load("res://view/battle/battle_screen.gd").new()
	viewport.add_child(battle)
	battle.local_id = "p"
	battle.show_state(f.state, 1)
	return battle

func host_of(battle: Control, socket: int) -> Control:
	return battle._rail_box.get_child(socket)

func moons_of(host: Control) -> Array:
	return host.get_node("Riders").get_children().filter(func(c: Node) -> bool: return bool(c.get_meta("moon", false)))

func count_of(host: Control) -> Control:
	for child in host.get_node("Riders").get_children():
		if child is VoidMarks.CountMark:
			return child
	return null

func phantoms(f: Dictionary, copies: Dictionary, thrown: Array) -> void:
	## Phantom rolls in the hand: `copies` {source die id: count}, `thrown` [[shape, value, count]].
	var me: Dictionary = f.state.players[0]
	var hand: Array = me.hand.filter(func(r: Dictionary) -> bool: return not bool(r.get("phantom", false)))
	var n: int = 0
	for source_id in copies:
		for k in range(int(copies[source_id])):
			n += 1
			hand.append({"die_id": "%s_ph%d" % [source_id, n], "value": 3, "face": 2, "shape": "D6", "kind": "plain", "phantom": true, "source_id": source_id})
	for entry in thrown:
		for k in range(int(entry[2])):
			n += 1
			hand.append({"die_id": "p_roll%d" % n, "value": int(entry[1]), "face": int(entry[1]) - 1, "shape": str(entry[0]), "kind": "plain", "phantom": true, "source_id": ""})
	me.hand = hand

func labels_in(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for child in node.get_children():
		labels_in(child, out)

# --- the numbers ---------------------------------------------------------------------------------

func _numbers() -> void:
	check(VoidMarks.short_count(999) == "999" and VoidMarks.short_count(1458) == "1.4k" and VoidMarks.short_count(12000) == "12k" and VoidMarks.short_count(1200000) == "1.2M", "a count stays short: 999, 1.4k, 12k, 1.2M (%s %s %s %s)" % [VoidMarks.short_count(999), VoidMarks.short_count(1458), VoidMarks.short_count(12000), VoidMarks.short_count(1200000)])
	check(VoidMarks.with_commas(1458) == "1,458" and VoidMarks.with_commas(12) == "12" and VoidMarks.with_commas(1000000) == "1,000,000", "the exact count reads with commas")
	check(VoidMarks.pages_of(5, 14) == [[0, 5]] and VoidMarks.pages_of(18, 14) == [[0, 13], [13, 18]], "a popout pages past two rows, a place each for the page buttons: %s" % str(VoidMarks.pages_of(18, 14)))
	check(VoidMarks.pages_of(40, 14).size() == 4 and int(VoidMarks.pages_of(40, 14).back()[1]) == 40, "every run lands on some page")

# --- the desktop ---------------------------------------------------------------------------------

func _desk() -> void:
	var f: Dictionary = fight([["VENOM", "TITHE", "LUCKY_SEVEN", "CRUSH", "BLOOM"], ["HEX", "PRISM"], [], ["ANCHOR", "GRAFT"]])
	var battle: Control = screen_for(f)
	await process_frame
	await process_frame
	var me: Dictionary = f.state.players[0]
	var rail: Array = me.rail
	check(battle._socket_cards.size() == rail.size() and battle._socket_cards.all(func(c: Variant) -> bool: return c is Control), "every gem and rider on the flat rail has a card or a moon to light (%d)" % battle._socket_cards.size())
	## Five riders: two moons and a "+3".
	var first: Control = host_of(battle, 0)
	var moons: Array = moons_of(first)
	var count: Control = count_of(first)
	check(moons.size() == 2 and count != null and count.more == 3 and count.text == "+3", "five riders on a socket are two icon moons and a +3 (%d moons, %s)" % [moons.size(), str(count.text) if count != null else "no count"])
	check(moons.size() == 2 and moons[0].position.x > first.get_node("Main").size.x * 0.5, "the moons stand on the ring's right side")
	var folded: int = 0
	for index in range(rail.size()):
		var place: Dictionary = DeepStone.place_of(me, index)
		if int(place.socket) == 0 and int(place.rider) >= 2 and battle._socket_cards[index] == count:
			folded += 1
	check(folded == 3, "the riders past the moons are lit through the count (%d of 3)" % folded)
	## Two riders: a moon each, no count.
	var second: Control = host_of(battle, 1)
	check(moons_of(second).size() == 2 and count_of(second) == null, "two riders are two moons and no count")
	## An empty socket's first rider stands in its ring, in the Hollow look; the second is a moon.
	var fourth: Control = host_of(battle, 3)
	var front: Control = fourth.get_node("Main")
	var picture: Variant = front.get_node_or_null("Slot/Gem")
	var ring: Variant = front.get_node_or_null("Slot/Ring")
	check(bool(front.get_meta("front", false)) and picture != null and bool(picture.get("hollow")) and picture.material != null, "an empty socket's first rider sits in its ring in the Hollow look")
	check(ring != null and str(ring.get("color")) != "VOID", "and the ring is the socket's own, not a dashed Void ring (%s)" % str(ring.get("color")) if ring != null else "no ring")
	check(moons_of(fourth).size() == 1, "its other rider is a moon")
	var said: Label = front.get_node_or_null("NameRow/SkillName")
	check(said != null and said.get_theme_color(&"font_color").is_equal_approx(DeepUi.INFO), "the stand-in's name is the Void's blue")
	## The figure sits in the name row on a desk, beside the name, and alone when too long.
	var strike: Control = host_of(battle, 0).get_node("Main")
	var fire: Label = strike.get_node_or_null("NameRow/Fire")
	check(fire != null and strike.get_node_or_null("Slot/Fire") == null, "the figure a lit gem wears lives in the name row on a desk")
	if fire != null:
		var name_label: Label = strike.get_node("NameRow/SkillName")
		fire.text = "3"
		fire.visible = true
		fire.reset_size()
		battle._settle_figures()
		check(name_label.visible and fire.position.x > strike.get_node("NameRow").custom_minimum_size.x * 0.5 and fire.get_theme_font_size(&"font_size") == battle.FIGURE_PX, "a short figure stands to the right of its name, the name staying put")
		fire.text = "482915"
		fire.reset_size()
		battle._settle_figures()
		check(name_label.visible and fire.position.x > strike.get_node("NameRow").custom_minimum_size.x * 0.5, "six digits still fit beside a short name before the next one")
		fire.text = "+48,291,500"
		fire.reset_size()
		battle._settle_figures()
		check(not name_label.visible and fire.get_theme_font_size(&"font_size") == battle.FIGURE_ALONE_PX, "a figure too long for the room before the next name takes the name's place alone")
		fire.text = "3"
		fire.reset_size()
		battle._settle_figures()
		check(name_label.visible, "and gives it back when it is short again")
	## The popout: every rider at full size, in order, each a disc an event can light.
	var page: RefCounted = battle._local_page
	battle._open_riders(page, 0, 0, false)
	await process_frame
	var pop: Variant = page.riders_pop
	check(pop != null and is_instance_valid(pop) and pop.runs.size() == 5, "the popout lays a socket's five riders out as five stones")
	var lit_all: bool = true
	for index in range(rail.size()):
		var place: Dictionary = DeepStone.place_of(me, index)
		if int(place.socket) == 0 and int(place.rider) >= 0:
			if pop == null or pop.element_for(index) == null or battle._gem_card("p", index) != pop.element_for(index):
				lit_all = false
	check(lit_all, "while it is open, each rider's disc is the card its events land on")
	check(battle._riders_catch != null and battle._riders_catch.visible, "a pane under it catches the click that closes it")
	battle._close_riders(page)
	check(page.riders_pop == null and not battle._riders_catch.visible, "closed, it is gone and the pane with it")
	battle.free()
	await process_frame
	## An Echo's run of copies is one stone with a ×N, and twenty runs page.
	f = fight([["VENOM", "TITHE"]], 0, 40)
	battle = screen_for(f)
	await process_frame
	me = f.state.players[0]
	count = count_of(host_of(battle, 0))
	check(count != null and count.more == 40 and count.text == "+40", "forty-two riders show two moons and a +40 (%s)" % (str(count.text) if count != null else "no count"))
	page = battle._local_page
	battle._open_riders(page, 0, 0, false)
	await process_frame
	pop = page.riders_pop
	check(pop != null and pop.runs.size() == 3 and pop.runs[2].flats.size() == 40, "forty copies of one gem standing together are one run (%d runs)" % (pop.runs.size() if pop != null else -1))
	var texts: Array = []
	labels_in(pop, texts)
	check(texts.any(func(l: Label) -> bool: return l.text == "×40"), "with a ×40 on it")
	check(pop.pages.size() == 1, "three runs are one page")
	## Firing: the run counts down and the popout turns to the firing rider's page.
	var venoms: Array = []
	for index in range(me.rail.size()):
		if me.rail[index] is Dictionary and str(me.rail[index].get("skill", "")) == "VENOM" and str(me.rail[index].get("id", "")).contains("void"):
			venoms.append(index)
	for k in range(10):
		page.outcomes[venoms[k]] = true
	pop.mark_fired(page.outcomes, venoms[9], false)
	labels_in(pop, texts)
	texts = []
	labels_in(pop, texts)
	check(texts.any(func(l: Label) -> bool: return l.text == "×30"), "as ten of them fire, the tag counts down to ×30")
	battle._close_riders(page)
	battle.free()
	await process_frame
	## Twenty runs page.
	var many: Array = []
	for key in ["VENOM", "TITHE", "LUCKY_SEVEN", "CRUSH", "BLOOM", "HEX", "PRISM", "ECHO", "TUMBLE", "CLEAVE", "EMBER", "TEMPO", "ANCHOR", "GRAFT", "MIASMA", "MIST", "JACKPOT", "GLIMMER", "CASCADE", "FACET"]:
		many.append(key)
	f = fight([many])
	battle = screen_for(f)
	await process_frame
	page = battle._local_page
	battle._open_riders(page, 0, 0, false)
	await process_frame
	pop = page.riders_pop
	check(pop != null and pop.pages.size() == 2 and pop.element_for(int(pop.runs[15].flats[0])) == null, "twenty runs take two pages, the later ones out of sight")
	battle._open_riders(page, 0, 1, false)
	await process_frame
	pop = page.riders_pop
	check(pop != null and pop.page == 1 and pop.element_for(int(pop.runs[15].flats[0])) != null, "turned, the second page shows them")
	check(pop.page_of(int(pop.runs[2].flats[0])) == 0 and pop.page_of(int(pop.runs[15].flats[0])) == 1, "the popout knows which page a rider stands on")
	battle._close_riders(page)
	## The counter of plays, and the rail spent.
	page.plays = 20
	f.state.phase = "resolving"
	battle._show_plays(page)
	check(page.plays_label != null and page.plays_label.visible and page.plays_label.text.begins_with("20 / %d plays" % DeepBattle.RAIL_CAP), "past the twelfth play a counter says how far the rail has come: %s" % page.plays_label.text)
	battle._rail_spent({"unit": "p", "plays": DeepBattle.RAIL_CAP, "dropped": 7})
	check(page.spent and not page.plays_label.visible, "a spent rail is marked and its counter goes")
	f.state.phase = "planning"
	battle.free()
	await process_frame
	## The float row: one die a copy while they fit, with the thrown dice leftmost.
	f = fight([])
	phantoms(f, {"p_d0": 3}, [["D6", 4, 2]])
	battle = screen_for(f)
	await process_frame
	await process_frame
	page = battle._local_page
	var row: Variant = page.phantom_row
	check(row != null and row.visible and row.mode == "single" and row.entries.size() == 5, "five phantoms hang over the tray one die each (%s, %d)" % [str(row.mode) if row != null else "no row", row.entries.size() if row != null else -1])
	check(row.entries.size() == 5 and str(row.entries[0].kind) == "thrown" and str(row.entries[4].kind) == "copy", "the thrown dice stand leftmost, the copies after them")
	check(row.items.size() == 5 and battle._phantom_views.size() == 5 and battle._counted_die("p_d0_ph1") != null, "each die is a thing a count can point at")
	check(row.entries.all(func(e: Dictionary) -> bool: return bool(e.view.get("hollow")) and e.view.material != null), "every phantom is drawn in the Hollow look")
	## Too many to fit: stacks, one a source, with a ×N.
	phantoms(f, {"p_d0": 60, "p_d1": 2}, [["D6", 4, 5]])
	battle.show_state(f.state, 1)
	await process_frame
	check(row.mode == "stacks" and row.entries.size() == 3, "sixty-seven phantoms stack by the die they copy (%s, %d)" % [str(row.mode), row.entries.size()])
	var tagged: Array = row.entries.filter(func(e: Dictionary) -> bool: return e.has("tag") and e.tag != null)
	check(tagged.size() == 3 and tagged.any(func(e: Dictionary) -> bool: return (e.tag.get_node("Value") as Label).text == "×60"), "with a tag each, ×60 on the big one")
	check(row.items.size() == 67 and row.items["p_d0_ph1"] == row.items["p_d0_ph60"], "a stack answers for every die in it")
	## More thrown stacks than the row holds fold into a +N at the far left.
	var spread: Array = []
	for value in range(1, 21):
		spread.append(["D20", value, 2])
	phantoms(f, {"p_d0": 60}, spread)
	battle.show_state(f.state, 1)
	await process_frame
	check(row.mode == "stacks" and str(row.entries[0].kind) == "more" and row.fold != null and int(row.entries[0].count) > 0, "thrown stacks past the room fold into a +N at the far left (%s)" % (str(row.fold.text) if row.fold != null else "none"))
	check(str(row.entries.back().kind) == "copy", "and the copies always show")
	battle.free()
	await process_frame

# --- the phone -----------------------------------------------------------------------------------

func _phone() -> void:
	DeepUi.phone = true
	DeepUi.safe_left = DeepUi.PHONE_SAFE_SIDE
	DeepUi.safe_right = DeepUi.PHONE_SAFE_SIDE
	DeepUi.safe_bottom = DeepUi.PHONE_SAFE_FOOT
	var screen_class = load("res://view/battle/battle_screen.gd")
	screen_class.use_phone_sizes()
	viewport.size = DeepUi.PHONE_CANVAS
	var f: Dictionary = fight([["VENOM", "TITHE", "LUCKY_SEVEN", "CRUSH", "BLOOM"], ["HEX", "PRISM"], [], ["ANCHOR", "GRAFT"]])
	var battle: Control = screen_for(f)
	await process_frame
	await process_frame
	var first: Control = host_of(battle, 0)
	var count: Control = count_of(first)
	check(moons_of(first).size() == 1 and count != null and count.more == 4, "on the phone the arc holds two marks: one moon and a +4 (%d moons, %s)" % [moons_of(first).size(), str(count.text) if count != null else "no count"])
	check(count != null and count.font_px >= DeepUi.min_text(), "the count's number meets the text floor (%d of %d)" % [count.font_px if count != null else 0, DeepUi.min_text()])
	check(count != null and count.mouse_filter == Control.MOUSE_FILTER_IGNORE and bool(first.get_meta("tap_wired", false)), "the socket itself is the tap target, not the small marks")
	check(first.size.x >= DeepUi.pt(DeepUi.FINGER_LEAST) and first.size.y >= DeepUi.pt(DeepUi.FINGER_LEAST), "and it is finger-sized (%s)" % str(first.size))
	var strike: Control = first.get_node("Main")
	check(strike.get_node_or_null("Slot/Fire") != null and strike.get_node_or_null("NameRow/Fire") == null, "the figure lives in the slot on the phone, which has no names")
	var page: RefCounted = battle._local_page
	battle._open_riders(page, 0, 0, false)
	await process_frame
	var pop: Variant = page.riders_pop
	var buttons: Array = []
	for child in pop.get_children():
		if child is Button:
			buttons.append(child)
	check(pop != null and buttons.size() == 1 and buttons[0].size.x >= DeepUi.pt(44) - 0.5 and buttons[0].size.y >= DeepUi.pt(44) - 0.5, "the popout's × is a 44 point pad (%s)" % (str(buttons[0].size) if not buttons.is_empty() else "no button"))
	check(pop.position.x >= DeepUi.safe_left - 0.5 and pop.position.x + pop.size.x <= float(viewport.size.x) - DeepUi.safe_right + 0.5, "it keeps inside the safe edges")
	var small: Array = []
	labels_in(pop, small)
	check(small.all(func(l: Label) -> bool: return l.text.is_empty() or l.get_theme_font_size(&"font_size") >= DeepUi.min_text()), "every word on it meets the text floor")
	battle._close_riders(page)
	battle.free()
	await process_frame
	## Twenty runs: the page button is a finger pad too.
	var many: Array = ["VENOM", "TITHE", "LUCKY_SEVEN", "CRUSH", "BLOOM", "HEX", "PRISM", "ECHO", "TUMBLE", "CLEAVE", "EMBER", "TEMPO", "ANCHOR", "GRAFT", "MIASMA", "MIST", "JACKPOT", "GLIMMER", "CASCADE", "FACET"]
	f = fight([many])
	battle = screen_for(f)
	await process_frame
	page = battle._local_page
	battle._open_riders(page, 0, 0, false)
	await process_frame
	pop = page.riders_pop
	buttons = []
	for child in pop.get_children():
		if child is Button and child.text == "›":
			buttons.append(child)
	check(pop.pages.size() == 2 and buttons.size() == 1 and buttons[0].size.x >= DeepUi.pt(44) - 0.5, "the page button is a 44 point pad")
	battle._close_riders(page)
	## The row on the phone keeps its tags at the text floor.
	phantoms(f, {"p_d0": 60, "p_d1": 2}, [["D6", 4, 5]])
	battle.show_state(f.state, 1)
	await process_frame
	await process_frame
	var row: Variant = page.phantom_row
	var tags: Array = []
	labels_in(row, tags)
	check(row.mode == "stacks" and not tags.is_empty() and tags.all(func(l: Label) -> bool: return l.get_theme_font_size(&"font_size") >= DeepUi.min_text()), "a stack's tag on the phone meets the text floor")
	battle.free()
	await process_frame
	DeepUi.phone = false
