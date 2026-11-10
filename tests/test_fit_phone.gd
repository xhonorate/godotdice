extends SceneTree
## The phone's layout (docs/PHONE_UI.md): every screen, drawn on the phone's canvas (852 × 393
## points, 1704 × 786 canvas pixels, an iPhone's safe insets), fits inside it, and only what the
## phone may scroll scrolls (`may_scroll`); no word is set under the phone's text floor
## (PHONE_LEAST points); every button a finger presses is at least FINGER points across and
## stands inside the screen's safe edges.
##
## Each screen is filled as full as a player can make it, as tests/test_fit.gd fills the desk's.

const Homecoming = preload("res://view/home/homecoming.gd")

## The least a button stands, either way, in points: the strip's and the tabs' size; their
## touch areas reach further (DeepUi.reach), which counts.
const FINGER: float = DeepUi.FINGER_LEAST

var checks: int = 0
var failures: Array = []
var screen: SubViewport
var canvas: Vector2

func _init() -> void:
	OS.set_environment("DEEPCUT_FORM", "phone")
	DeepSaveStore.override_directory = "user://test_scratch_phone"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	canvas = Vector2(DeepUi.PHONE_CANVAS)
	screen = SubViewport.new()
	screen.size = DeepUi.PHONE_CANVAS
	root.add_child(screen)
	var app: Control = load("res://view/app.gd").new()
	screen.add_child(app)
	await process_frame
	check(DeepUi.phone, "the phone form is on with DEEPCUT_FORM=phone")
	check(DeepUi.safe_left > 0.0 and DeepUi.safe_bottom > 0.0, "a desk window in the phone form takes an iPhone's safe insets (%d, %d)" % [int(DeepUi.safe_left), int(DeepUi.safe_bottom)])
	check(DeepUi.min_text() == int(DeepUi.PHONE_LEAST * DeepUi.PT), "the phone's text floor is %d points" % DeepUi.PHONE_LEAST)
	_fill(app.profile)
	app._profile_changed()
	await _workshop(app)
	await _swipes(app)
	_conquest_map()
	await _menu(app)
	await _inspector(app)
	await _popups(app)
	await _run(app)
	print("Fit (phone): %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

# --- the workshop ------------------------------------------------------------------------------

func _workshop(app: Control) -> void:
	var home: Control = app.home
	var lobby: Dictionary = app.session.lobby.duplicate(true)
	for i in range(1, 4):
		var id: String = "p%d" % i
		lobby.order.append(id)
		lobby.members[id] = {"name": "Guest With A Long Name %d" % i, "character": "VESPER", "ready": i % 2 == 0, "connected": true,
			"showcase": app.profile.vault.values().slice(0, 7)}
	home.refresh(app.profile, lobby, "hosting", true, app.session.local_id, false, app.settings, "")
	app._rename_player("W".repeat(DeepProfile.NAME_LIMIT))
	## The places down the left: the rail, not a bar along the top.
	check(home.find_child("Tab_map", true, false) != null or home.find_child("Tab_descend", true, false) != null, "the workshop's places stand on the rail")
	home.open("map")
	await _fits(screen, "Descend (the expedition)")
	app.session.choose_daily(DeepEconomy.today())
	home.open("map")
	await _fits(screen, "Descend (the daily dig)")
	app.session.choose_mine(DeepContent.starter_mine())
	home._party_open = true
	home._render()
	await _fits(screen, "the party panel")
	home._party_open = false
	home.open("roster")
	await _fits(screen, "a delver's dossier")
	home._roster_view = "sockets"
	home.open("roster", true)
	await _fits(screen, "a delver's sockets")
	home._vault_view = "collection"
	home.open("vault", true)
	await _fits(screen, "the vault")
	home._vault_view = "unappraised"
	home.open("vault", true)
	await _fits(screen, "the tray's bench")
	for tab in ["case", "geodes", "commissions", "bench"]:
		home.set_meta("market_tab", tab)
		home.open("market")
		await _fits(screen, "the market's %s" % tab)
	## The Wheel's, the Oven's and the contract's own pages (November 9, 2026: they ran off the
	## phone's right edge), with a stone picked and without, and a contract with five on it.
	var kept: Array = home.profile.get("vault", {}).keys()
	for kind in ["wheel", "oven"]:
		for pick in ["", str(kept[0]) if not kept.is_empty() else ""]:
			home._market_view = kind
			home._rework_pick = pick
			home.open("market", true)
			await _fits(screen, "the market's %s%s" % [kind, " with a stone picked" if not pick.is_empty() else ""])
	home._rework_pick = ""
	home._market_view = "contract"
	home._contract = []
	home.open("market", true)
	await _fits(screen, "the contract bench, empty")
	for tier in DeepEconomy.CONTRACT_TIERS:
		var five: Array = DeepEconomy.cheapest_contract(home.profile, str(tier))
		if five.size() >= DeepEconomy.contract_size():
			home._contract = five
			home.open("market", true)
			await _fits(screen, "the contract bench with five on it")
			break
	home._contract = []
	home._market_view = "main"
	home.open("bestiary")
	await _fits(screen, "the bestiary")
	for key in ["THE_FOREMAN", "MAGPIE"]:
		load("res://view/home/bestiary_page.gd").call("pick", home, key)
		for leaf in range(4):
			home._bestiary_leaf = leaf
			home._render()
			await _fits(screen, "the bestiary on %s, page %d" % [key, leaf + 1])
	for tab in ["showcase", "mines", "runs"]:
		home.set_meta("you_tab", tab)
		home.open("ledger")
		await _fits(screen, "You (%s)" % tab)
	home.open("map")

# --- a sideways flick turns a page's tabs (view/ui/swipe.gd) ---------------------------------------

var _pointer: Vector2 = Vector2.ZERO

func _swipes(app: Control) -> void:
	var home: Control = app.home
	var Swipe: Script = load("res://view/ui/swipe.gd")
	## What a movement says, on its own: a tap, a list's scroll and a slow drag say nothing.
	var far: float = DeepUi.pt(120)
	check(Swipe.call("reads", Vector2(-far, 0), 0.0, 200) == 1 and Swipe.call("reads", Vector2(far, 10), 10.0, 200) == -1, "a flick left is the next tab, right the one before")
	check(Swipe.call("reads", Vector2(4, 3), 3.0, 120) == 0, "a tap is not a flick")
	check(Swipe.call("reads", Vector2(-far * 0.4, -far * 1.2), far * 1.2, 300) == 0, "a list scrolled up or down is not a flick")
	check(Swipe.call("reads", Vector2(-far, 0), far * 0.8, 300) == 0, "nor is a drag that wandered up and down on its way across")
	check(Swipe.call("reads", Vector2(-far, 0), 0.0, 1500) == 0, "nor a slow drag")
	## On the Descend page: Expedition, then the Daily dig, and back.
	app.session.choose_daily("")
	app.session.choose_mine(DeepContent.starter_mine())
	home.open("map")
	await _frames(3)
	check(str(app.session.lobby.get("daily", "")).is_empty(), "the Descend page starts on the expedition")
	check(home.find_child("Swipe", false, false) != null, "the phone's workshop watches for flicks")
	var mid: Vector2 = home._body.get_global_rect().get_center()
	await _flick(mid, mid + Vector2(-far, 6))
	check(not str(app.session.lobby.get("daily", "")).is_empty(), "a flick left over the Descend page opens the Daily dig")
	await _flick(mid, mid + Vector2(far, 0))
	check(str(app.session.lobby.get("daily", "")).is_empty(), "and a flick right goes back to the expedition")
	await _flick(mid, mid + Vector2(far, 0))
	check(str(app.session.lobby.get("daily", "")).is_empty(), "past the first tab a flick does nothing")
	var picked: String = str(app.session.lobby.get("mine", ""))
	await _flick(mid, mid + Vector2(DeepUi.pt(8), far))
	check(str(app.session.lobby.get("daily", "")).is_empty() and str(app.session.lobby.get("mine", "")) == picked, "a drag down the page turns nothing and picks nothing")
	## You's tabs, and the Market's.
	home.set_meta("you_tab", "showcase")
	home.open("ledger")
	await _frames(3)
	await _flick(mid, mid + Vector2(-far, 0))
	check(str(home.get_meta("you_tab", "")) == "mines", "a flick left over You opens Mines (got %s)" % str(home.get_meta("you_tab", "")))
	home.set_meta("market_tab", "case")
	home.open("market")
	await _frames(3)
	await _flick(mid, mid + Vector2(-far, 0))
	check(str(home.get_meta("market_tab", "")) == "geodes", "a flick left over the Market opens Geodes (got %s)" % str(home.get_meta("market_tab", "")))
	## A card over the page takes the flick for itself.
	home._party_open = true
	home._render()
	await _frames(3)
	await _flick(mid, mid + Vector2(far, 0))
	check(str(home.get_meta("market_tab", "")) == "geodes", "a flick over the party's panel turns nothing under it")
	home._party_open = false
	home.set_meta("market_tab", "case")
	home.set_meta("you_tab", "showcase")
	home.open("map")
	await _frames(2)

func _flick(from: Vector2, to: Vector2) -> void:
	_mouse(from, true)
	for step in range(1, 7):
		_mouse(from.lerp(to, float(step) / 6.0))
	_mouse(to, false)
	await _frames(4)

func _mouse(at: Vector2, pressed: Variant = null) -> void:
	if pressed == null:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.relative = at - _pointer
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		screen.push_input(motion)
	else:
		var button := InputEventMouseButton.new()
		button.position = at
		button.global_position = at
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = bool(pressed)
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if bool(pressed) else 0
		screen.push_input(button)
	_pointer = at

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

# --- the beaten mine's sheet ---------------------------------------------------------------------

func _conquest_map() -> void:
	## The map's rows stand inside the map: a long name beside "Just opened" ran into the page
	## beside it (November 10, 2026).
	var Sheet: Script = load("res://view/inspect/conquest_sheet.gd")
	var order: Array = DeepContent.mines_in_order()
	for index in range(order.size() - 1):
		var here: String = str(order[index])
		var next: String = str(order[index + 1])
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(DeepUi.pt(240), 0)
		screen.add_child(stage)
		var records: Dictionary = {}
		for key in order.slice(0, index + 2):
			records[str(key)] = {"unlocked": true, "boss": str(key) != next}
		Sheet.call("map", stage, {"mine": here, "next": next, "opened": next, "depth": 32, "fare": 12345, "records": records})
		var rows: Control = stage.get_child(0)
		check(stage.custom_minimum_size.x >= rows.get_combined_minimum_size().x, "the beaten %s's map holds its rows (%d wide in %d)" % [here, int(rows.get_combined_minimum_size().x), int(stage.custom_minimum_size.x)])
		stage.free()

func _menu(app: Control) -> void:
	app.open_menu()
	await _fits(app.menu, "the menu")
	for page in ["settings", "controls", "quit", "player_name"]:
		app.menu._show(page)
		await _fits(app.menu, "the menu's %s page" % page)
	app.menu.close()
	app.menu.open_settings(app.settings, app._menu_context())
	await _fits(app.menu, "the settings, opened from You")
	app.menu.close()

func _inspector(app: Control) -> void:
	var inspector: Script = load("res://view/inspect/inspector.gd")
	var keys: Array = app.profile.vault.keys()
	keys.sort()
	for key in keys.slice(0, 6):
		inspector.call("stone", app.profile.vault[key])
		await _fits(root, "the close look at %s" % str(key))
	inspector.call("die", app.profile.bowl[app.profile.bowl.size() - 1])
	await _fits(root, "the close look at a die")
	for key in ["MAGPIE", "THE_FOREMAN"]:
		inspector.call("creature", DeepCreatures.make(key, "phone_" + key, 1, 1))
		await _fits(root, "the close look at %s" % key)
	inspector.call("close")
	await process_frame
	await process_frame

# --- popups (November 10, 2026) -------------------------------------------------------------------

func _popups(app: Control) -> void:
	## The appraisal with the most it can say (the longest skill, up to four inclusions, a stone of
	## its skill on the rail to swap, a refusal said in full) keeps its choices on the screen; the
	## close look's pills wrap inside it; a long toast wraps inside it.
	var skill: String = ""
	var most: int = -1
	for key in DeepContent.section("skills"):
		var said: int = str(DeepContent.skill(str(key)).get("text", "")).length() + 8 * str(DeepContent.skill(str(key)).get("name", "")).length()
		if str(DeepContent.skill(str(key)).get("rarity", "")) != "BIRTHSTONE" and said > most:
			most = said
			skill = str(key)
	var inclusions: Array = DeepContent.section("inclusions").keys()
	inclusions.sort_custom(func(a: Variant, b: Variant) -> bool: return str(DeepContent.inclusion(str(a)).get("text", "")).length() > str(DeepContent.inclusion(str(b)).get("text", "")).length())
	var skill_name: String = str(DeepContent.skill(skill).get("name", ""))
	for count in [0, 2, 4]:
		var raw: Dictionary = DeepStone.make(skill, 22, 3, 1, inclusions.slice(0, count), {"run": "fit"}, "fit_appraisal_%d" % count)
		raw.appraised = false
		var kept: Dictionary = DeepStone.make(skill, 9, 2, 3, [], {"run": "fit"}, "fit_kept")
		kept.appraised = true
		var actions: Array = [
			{"label": "Swap for your %s (socket 3)" % skill_name, "glyph": "gem", "tone": DeepUi.GOOD, "caption": "Your 9 ct %s goes in the bag" % skill_name, "compare": {"found": raw, "kept": kept}},
			{"label": "Into the bag", "glyph": "bag", "tone": DeepUi.ACCENT, "caption": "It would be a second of a gem already on your rail, which nobody may carry", "dismiss": true},
			{"label": "Sell for 1234 pyrite", "glyph": "scales", "tone": DeepUi.ORE, "caption": "Half its worth, on the scales"}]
		var layer: CanvasLayer = load("res://view/gems/appraisal.gd").new()
		screen.add_child(layer)
		layer.call("build", raw, {"actions": actions})
		layer.call("finish")
		await _frames(4)
		await _fits(layer, "the appraisal of a %s with %d inclusions" % [skill_name, count])
		var buttons: Array = (layer.get("_choices") as Control).find_children("*", "Button", true, false)
		check(not buttons.is_empty() and buttons.all(func(b: Button) -> bool: return Rect2(Vector2.ZERO, canvas).encloses(b.get_global_rect())),
			"the appraisal's choices stand on the screen with %d inclusions" % count)
		layer.free()
	## The close look at a stone kept at home and priced in the case: five pills under its name.
	var Inspector: Script = load("res://view/inspect/inspector.gd")
	var stone: Dictionary = app.profile.vault.values()[0].duplicate(true)
	stone.id = "fit_other_copy"
	Inspector.set("vault", {str(stone.skill): app.profile.vault.values()[0]})
	var sheet: CanvasLayer = Inspector.new()
	screen.add_child(sheet)
	sheet.call("_frame", DeepUi.ACCENT, {})
	sheet.call("_fill_stone", stone, {"market": {"price": 123456, "call": func() -> void: pass}})
	await _frames(4)
	var panel: Control = sheet.get("_panel")
	check(Rect2(Vector2.ZERO, canvas).grow(1.5).encloses(panel.get_global_rect()), "the close look with five pills under its name stays on the screen (%s)" % _rect(panel.get_global_rect()))
	sheet.free()
	Inspector.set("vault", {})
	## A toast too long for one line wraps inside the screen.
	app.toast("A very long toast that says something about a stone and a die and how the market treats them both when nobody is looking at it.", DeepUi.ACCENT, "spark")
	await _frames(3)
	var toasts: Control = app.get("_toasts")
	check(toasts.get_child_count() > 0 and Rect2(Vector2.ZERO, canvas).encloses(toasts.get_global_rect()), "a long toast wraps inside the screen (%s)" % _rect(toasts.get_global_rect()))
	for toast in toasts.get_children():
		toast.free()

# --- down the mine -----------------------------------------------------------------------------

func _run(app: Control) -> void:
	app._depart(9001)
	await process_frame
	await process_frame
	var descent: Control = app.descent
	descent.show_state(app.session.run)
	await _fits(screen, "the grubstake")
	## Every oddity, smithy and carver: its card along the bottom of its room, and the way out
	## in the room's corner, clear of the cards.
	var room: Dictionary = app.session.run.duplicate(true)
	room.phase = "chamber"
	for key in DeepContent.section("oddities"):
		room.chamber = {"kind": "oddity", "oddity": str(key), "results": {}, "depth": 1, "settled": false}
		for kind in DeepDescent.CARD_ROOMS:
			if DeepDescent.room_card(kind) == str(key):
				room.chamber.kind = kind
		descent.show_state(room)
		await _fits(screen, "the %s's card" % str(key))
		_way_out_clear(descent, "the %s's card" % str(key))
		_in_room(descent, "the %s's card" % str(key))
		await _asks_fit(descent, room, str(key))
	descent.show_state(app.session.run)
	var seen: Dictionary = {}
	for step in range(400):
		var run: Dictionary = app.session.run
		var phase: String = str(run.get("phase", ""))
		if phase == "tunnels" and not seen.has("tunnels") and int(run.get("depth", 0)) >= 1:
			seen.tunnels = true
			while descent.walking():
				await process_frame
			descent.show_state(run)
			await _fits(screen, "the crossroads")
			descent._run_dock.set_drawer(true)
			await _fits(screen, "the crossroads with the bag open")
			descent._run_dock.set_drawer(false)
			descent.toggle_chart()
			await _fits(screen, "the crossroads with the chart open")
			descent.toggle_chart()
			descent.open_bench("gems")
			await _fits(screen, "the bench's gems")
			descent.open_bench("dice")
			await _fits(screen, "the bench's dice")
			descent._bench.close()
			## A finger on a tunnel (November 10, 2026): held, it shows where the tunnel leads
			## and chooses nothing; a tap off the plate puts it away; a tap takes the tunnel at
			## once, no second tap. The fight the bot would take, so the run goes on as before.
			var offers: Array = descent._mouth_offers()
			var pick: int = 0
			for index in range(offers.size()):
				if str(offers[index].get("kind", "")) in ["fight", "elite"]:
					pick = index
			descent._stage.mouth_held.emit(pick)
			check(descent._chip_index == pick and descent._chip.visible, "a finger held on a tunnel shows where it leads")
			check(str(app.session.run.get("phase", "")) == "tunnels" and str(app.session.local_player().get("vote", "")).is_empty(), "and chooses nothing")
			descent._press_pick("")
			check(not descent._chip.visible, "a tap off the tunnel's plate puts it away")
			descent._choose_mouth(pick)
			await process_frame
			check(str(app.session.run.get("phase", "")) != "tunnels" or str(app.session.local_player().get("vote", "")) == str(offers[pick].id), "a tap on a tunnel takes it at once")
		if phase == "chamber" and DeepDescent.in_battle(run) and not seen.has("fight") and str(DeepDescent.battle(run).get("phase", "")) == "planning":
			seen.fight = true
			await _fits(screen, "a fight, planning")
		if phase == "landing" and not seen.has("landing"):
			seen.landing = true
			while descent.walking():
				await process_frame
			descent.show_state(run)
			await _fits(screen, "the landing")
		if seen.has("landing") and seen.has("fight") and seen.has("tunnels"):
			break
		_advance(app)
		await process_frame
	check(seen.size() == 3, "the run reached the crossroads, a fight and a landing (%s)" % str(seen.keys()))
	## The way out: the run abandoned, its end read.
	app.session.send({"kind": "abandon"})
	for i in range(240):
		if str(app.session.run.get("phase", "")) == "salvage":
			app.session.send({"kind": "ready"})
		if str(app.session.run.get("phase", "")) == "over":
			break
		await process_frame
	descent._end_shown = true
	descent.show_state(app.session.run)
	await _fits(screen, "the end of a run")
	descent._show_over_tab("haul")
	await _fits(screen, "the end of a run, its haul")

func _advance(app: Control) -> void:
	## One step of a run toward its next fight, taking the first of whatever is offered.
	var run: Dictionary = app.session.run
	if not app.session.local_player().get("twin", {}).is_empty():
		app.session.send({"kind": "twin", "choice": "toss"})
		return
	match str(run.get("phase", "")):
		"grubstake":
			if str(app.session.local_player().get("stake", "")).is_empty():
				var offer: Dictionary = run.grubstake.offers[app.session.local_id][0]
				app.session.send({"kind": "stake", "offer": offer.id, "payload": {"pick": 0} if offer.needs.has("pick") else {}})
		"tunnels":
			var offer: Dictionary = run.offers[0]
			for candidate in run.offers:
				if str(candidate.kind) in ["fight", "elite"]:
					offer = candidate
			app.session.send({"kind": "vote_tunnel", "offer": offer.id})
		"chamber":
			if DeepDescent.in_battle(run):
				var battle: Dictionary = DeepDescent.battle(run)
				for foe in battle.enemies:
					foe.hp = mini(int(foe.hp), 1)
				if str(battle.phase) == "planning":
					app.session.send({"kind": "lock"})
				else:
					app.session.tick(0.5)
			elif str(run.chamber.kind) in DeepDescent.ROCK_ROOMS:
				app.session.send({"kind": "stop_mining"})
			elif str(run.chamber.kind) in ["oddity"] + DeepDescent.CARD_ROOMS:
				var oddity: Dictionary = DeepContent.oddity(str(run.chamber.oddity))
				app.session.send({"kind": "oddity", "choice": oddity.choices[oddity.choices.size() - 1].id})
			elif str(run.chamber.kind) == "merchant":
				app.session.send({"kind": "leave"})
		"landing":
			if str(app.session.local_player().get("respite", "")).is_empty():
				app.session.send({"kind": "respite", "choice": "rest"})
			else:
				app.session.send({"kind": "choose", "choice": "descend"})
		"hoard":
			var mine_hoard: Dictionary = run.hoard[app.session.local_id]
			app.session.send({"kind": "pick_hoard", "stone_id": mine_hoard.offers[0].id})

# --- the checks ---------------------------------------------------------------------------------

func _fits(node: Node, what: String) -> void:
	## Twice round the loop, so every container has sorted its children.
	await process_frame
	await process_frame
	var found: Array = []
	_scan(node, Rect2(Vector2.ZERO, canvas), found)
	check(found.is_empty(), "%s fits the phone's screen: %s" % [what, "; ".join(found.slice(0, 4))])
	var small: Array = []
	_words(node, small)
	check(small.is_empty(), "%s sets no word under the phone's floor: %s" % [what, "; ".join(small.slice(0, 4))])
	var fingers: Array = []
	_fingers(node, fingers)
	check(fingers.is_empty(), "%s has no button too small for a finger or under a safe edge: %s" % [what, "; ".join(fingers.slice(0, 4))])

func _way_out_clear(descent: Node, what: String) -> void:
	## The way out of a page (a room's Leave it, a station's Back) is a key in a corner of the
	## room (November 9, 2026): it stands clear of the page's own cards and buttons.
	var key: Variant = descent._way_out_key
	if key == null or not is_instance_valid(key) or not (key as Control).is_visible_in_tree():
		return
	var rect: Rect2 = (key as Control).get_global_rect()
	var over: Array = []
	for thing in descent._page_things():
		if (thing as Rect2).intersects(rect):
			over.append(_rect(thing))
	check(over.is_empty(), "%s: the way out at %s stands clear of the page (%s)" % [what, _rect(rect), ", ".join(over)])

func _in_room(descent: Node, what: String) -> void:
	## A room's cards stand inside the room (over the dock's top) and clear of the room's name
	## and its line (November 9, 2026: the phone's Geode card stood over both).
	var room: Rect2 = (descent._page_holder as Control).get_global_rect().grow(2.0)
	var heads: Array = []
	for label in [descent._cross_title, descent._cross_sub]:
		if label != null and (label as Control).is_visible_in_tree() and not str(label.text).is_empty():
			heads.append((label as Control).get_global_rect())
	var bad: Array = []
	for thing in descent._page_things():
		if not room.encloses(thing):
			bad.append("past the room at %s" % _rect(thing))
		for head in heads:
			if (thing as Rect2).intersects(head):
				bad.append("over the name at %s" % _rect(thing))
	check(bad.is_empty(), "%s stands in the room, clear of its name: %s" % [what, ", ".join(bad)])

func _asks_fit(descent: Node, room: Dictionary, key: String) -> void:
	## Every piece of work asked on the ask sheet: the sheet stands over the dock, not on it
	## (November 9, 2026: on the phone it covered the rail's rings it asks you to tap).
	for choice in DeepContent.oddity(key).get("choices", []):
		if str(choice.get("needs", "")) in ["", "pattern", "offer"]:
			continue
		descent._oddity_step = str(choice.id)
		descent.show_state(room)
		await process_frame
		await process_frame
		var ask: Variant = descent._ask
		if ask == null or not ask.is_open() or ask._block == null:
			continue
		var sheet: Rect2 = (ask._block as Control).get_global_rect()
		var floor_at: float = (descent._page_holder as Control).get_global_rect().end.y
		check(sheet.end.y <= floor_at + 1.0, "the %s's ask for %s stands over the dock (its foot at %d, the dock's top at %d)" % [key, str(choice.id), int(sheet.end.y), int(floor_at)])
		descent._ask.close()
	descent._oddity_step = ""

func _shown(node: Node) -> bool:
	## A hidden layer (the menu put away) hides everything on it, as a hidden control does.
	if node is CanvasItem:
		return (node as CanvasItem).visible
	if node is CanvasLayer:
		return (node as CanvasLayer).visible
	return true

func _scan(node: Node, bounds: Rect2, found: Array) -> void:
	if not _shown(node):
		return
	if node is ScrollContainer:
		if not bool(node.get_meta("may_scroll", false)):
			found.append("%s scrolls" % _name(node))
			return
		var box := node as Control
		var window: Rect2 = box.get_global_rect()
		if window.size.x > 0.5 and window.size.y > 0.5 and not bounds.grow(1.5).encloses(window):
			found.append("%s at %s runs past %s" % [_name(box), _rect(window), _rect(bounds)])
		return
	var inner: Rect2 = bounds
	if node is Control and (node is Container or node.get_parent() is Container):
		var control := node as Control
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x > 0.5 and rect.size.y > 0.5 and not bounds.grow(1.5).encloses(rect):
			found.append("%s at %s runs past %s" % [_name(control), _rect(rect), _rect(bounds)])
			return
	if node is Control and (node as Control).clip_contents:
		inner = bounds.intersection((node as Control).get_global_rect())
	for child in node.get_children():
		_scan(child, inner, found)

func _words(node: Node, found: Array) -> void:
	## Every word on show at the phone's floor or larger.
	if not _shown(node):
		return
	if node is Label and not (node as Label).text.strip_edges().is_empty() and (node as Label).size.y > 0.5:
		var drawn: int = (node as Label).get_theme_font_size(&"font_size")
		if drawn < DeepUi.min_text():
			found.append("%s set at %d (floor %d)" % [_name(node), drawn, DeepUi.min_text()])
	elif node is Button and not (node as Button).text.strip_edges().is_empty() and (node as Button).size.y > 0.5:
		var drawn: int = (node as Button).get_theme_font_size(&"font_size")
		if drawn < DeepUi.min_text():
			found.append("%s set at %d (floor %d)" % [_name(node), drawn, DeepUi.min_text()])
	for child in node.get_children():
		_words(child, found)

func _fingers(node: Node, found: Array, scrolled: bool = false) -> void:
	## Every button on show that takes a press: FINGER points across either way (its reach
	## counted), and inside the screen's safe edges; one in a list that scrolls is brought
	## inside them by the scroll, whose window `_scan` holds to the screen.
	if not _shown(node):
		return
	if node is BaseButton and not (node as BaseButton).disabled and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		var button := node as Control
		var rect: Rect2 = button.get_global_rect()
		var reach: Node = button.get_node_or_null("Reach")
		if reach is Control:
			rect = rect.merge((reach as Control).get_global_rect())
		if rect.size.x > 0.5 and rect.size.y > 0.5:
			if minf(rect.size.x, rect.size.y) < DeepUi.pt(FINGER) - 0.5:
				found.append("%s is %dx%d" % [_name(button), int(rect.size.x), int(rect.size.y)])
			var safe := Rect2(Vector2(DeepUi.safe_left, DeepUi.safe_top), canvas - Vector2(DeepUi.safe_left + DeepUi.safe_right, DeepUi.safe_top + DeepUi.safe_bottom))
			## A way-out key may give way into a side's inset where the cards beside it come near
			## the edge (the owner allowed it, November 9, 2026), but most of it stays inside.
			var spare: float = button.size.x * 0.5 if button.has_meta("way_out") else 0.0
			if not scrolled and not safe.grow_individual(1.5 + spare, 1.5, 1.5 + spare, 1.5).encloses(button.get_global_rect()):
				found.append("%s at %s is under a safe edge" % [_name(button), _rect(button.get_global_rect())])
	for child in node.get_children():
		_fingers(child, found, scrolled or node is ScrollContainer)

func _name(node: Node) -> String:
	var parts: Array = []
	var at: Node = node
	while at != null and at != screen and at != root and parts.size() < 4:
		var label: String = at.get_class() if str(at.name).begins_with("@") else str(at.name)
		if at is Label:
			label += "'%s'" % (at as Label).text.left(24)
		elif at is Button:
			label += "'%s'" % (at as Button).text.left(24)
		parts.push_front(label)
		at = at.get_parent()
	return "/".join(parts)

func _rect(rect: Rect2) -> String:
	return "(%d,%d %dx%d)" % [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)]

# --- a full workshop ---------------------------------------------------------------------------

func _fill(profile: Dictionary) -> void:
	## As much as a player can have: every delver, a stone for every skill, a full tray, a long
	## ledger, every creature met.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var mine: Dictionary = DeepContent.mine(DeepContent.starter_mine())
	for key in DeepContent.characters_in_unlock_order():
		DeepProfile.unlock_character(profile, str(key))
	var guard: int = 0
	while profile.vault.size() < DeepContent.section("skills").size() and guard < 3000:
		guard += 1
		var stone: Dictionary = DeepForge.roll_stone(rng, mine, 4 + guard % 16, 4, {"run": "fit", "source": "vein", "mine": DeepContent.starter_mine(), "depth": 4 + guard % 16}, "fit_vault%d" % guard)
		stone.appraised = true
		stone.inclusions_revealed = true
		DeepProfile.keep(profile, stone)
	for i in range(14):
		var raw: Dictionary = DeepForge.roll_stone(rng, mine, 10 + i, 6, {"run": "fit", "source": "vein", "mine": DeepContent.starter_mine(), "depth": 10 + i}, "fit_tray%d" % i)
		if i % 3 == 0:
			raw.appraised = true
			raw.inclusions_revealed = true
		profile.tray.append(raw)
	for copy in range(4):
		for key in DeepContent.section("dice"):
			profile.bowl.append(DeepDice.make(str(key), "fit_bowl_%s_%d" % [key, copy]))
	profile.gold = 123456
	for i in range(40):
		profile.history.append({"date": "2026-08-%02d" % (1 + i % 28), "mine": DeepContent.starter_mine(), "depth": 4 + i % 20, "outcome": ["extracted", "fallen", "conquered"][i % 3], "stones": i % 9})
	profile.records.runs = 40
	profile.records.best_daily = 9999999
	var everywhere: Dictionary = {}
	for key in DeepContent.mines_in_order():
		everywhere[str(key)] = 99
	var index: int = 0
	for key in DeepContent.section("creatures"):
		profile.bestiary[str(key)] = {"met": 99999, "slain": 99999, "lost": 9999, "mines": everywhere.duplicate(), "first": "2026-10-15", "fresh": index % 2 == 0}
		index += 1

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
