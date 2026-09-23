extends SceneTree
## Every screen fits on one page: nothing scrolls, and nothing runs off the edge of the
## smallest canvas the game draws on (1600 × 900; a window of any other shape only adds room).
## Each screen is filled as full as a player can make it (a vault of every skill, a bowl of
## every lapidary's dice, a long ledger, a heavy haul) and every control on it must lie
## inside the screen and inside anything that clips it.

const CANVAS := Vector2i(1600, 900)

var checks: int = 0
var failures: Array = []
## The screen everything is drawn into. Headless, the window has no real size, so the game
## gets a viewport of its own at exactly the smallest canvas.
var screen: SubViewport

func _init() -> void:
	DeepSaveStore.override_directory = "user://test_scratch"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	screen = SubViewport.new()
	screen.size = CANVAS
	root.add_child(screen)
	var app: Control = load("res://view/app.gd").new()
	screen.add_child(app)
	await process_frame
	check(app.get_global_rect().size == Vector2(CANVAS), "the game is drawn on %s (got %s)" % [str(CANVAS), str(app.get_global_rect().size)])
	_fill(app.profile)
	app._profile_changed()
	await _workshop(app)
	await _menu(app)
	await _inspector()
	await _enemy_panels()
	await _appraisals(app)
	await _run(app)
	print("Fit: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

# --- the workshop ------------------------------------------------------------------------------

func _workshop(app: Control) -> void:
	var home: Control = app.home
	## A full party, and a Steam lobby's code on show.
	var lobby: Dictionary = app.session.lobby.duplicate(true)
	for i in range(1, 4):
		var id: String = "p%d" % i
		lobby.order.append(id)
		lobby.members[id] = {"name": "Guest With A Long Name %d" % i, "character": "VESPER", "ready": i % 2 == 0, "connected": true}
	home.refresh(app.profile, lobby, "hosting", true, app.session.local_id, false, app.settings, "109775241234567890")
	for tab in ["map", "roster", "vault", "appraise", "ledger"]:
		home.open(tab)
		await _fits(screen, "the %s tab" % tab)
	## The map's two side views, as the host and as a guest.
	for host in [true, false]:
		home.refresh(app.profile, lobby, "hosting" if host else "joined", host, app.session.local_id if host else "p1", false, app.settings, "109775241234567890")
		for side in ["expedition", "party"]:
			home._side = side
			home.open("map")
			await _fits(screen, "the map's %s view%s" % [side, "" if host else " for a guest"])
	home.refresh(app.profile, lobby, "hosting", true, app.session.local_id, false, app.settings, "109775241234567890")
	home._side = "expedition"
	## Every lapidary's dossier and sockets, with a socket picked.
	for key in DeepContent.characters_in_unlock_order():
		for view in ["dossier", "sockets"]:
			for picked in [-1, 0]:
				home._roster_pick = str(key)
				home._roster_view = view
				home._bench_socket = picked
				home.open("roster")
				await _fits(screen, "the Lapidaries tab on %s's %s%s" % [str(key), view, " with one picked" if picked >= 0 else ""])
	home._roster_pick = ""
	home._roster_view = "dossier"
	home._bench_socket = -1
	## Every page of the long lists.
	for list in ["vault_tray", "tray", "ledger"]:
		for page in range(3):
			home._pages[list] = page
			if list == "vault_tray":
				home._roster_view = "sockets"
			home.open({"vault_tray": "roster", "tray": "appraise", "ledger": "ledger"}[list])
			await _fits(screen, "page %d of the %s" % [page, list])
		home._pages[list] = 0
	home._roster_view = "dossier"
	## The vault, each color, with a stone under the lamp.
	home._vault_pick = str(app.profile.vault.keys()[0])
	for color in [""] + home.color_ORDER:
		home._vault_filter = color
		home.open("vault")
		await _fits(screen, "the vault filtered to '%s'" % color)
	home._vault_filter = ""
	## The tray, raw and appraised, and a stone whose skill is already kept.
	for stone in app.profile.tray:
		home._appraise_pick = str(stone.id)
		home.open("appraise")
		await _fits(screen, "the Appraise tab on %s" % DeepUi.stone_name(stone))
	## A known stone whose skill is not kept yet: keep or sell, nothing to weigh it against.
	var known: Dictionary = {}
	for stone in app.profile.tray:
		if bool(stone.get("appraised", false)):
			known = stone
	var kept: Dictionary = app.profile.vault.get(str(known.skill), {})
	app.profile.vault.erase(str(known.skill))
	home._appraise_pick = str(known.id)
	home.open("appraise")
	await _fits(screen, "the Appraise tab on a stone of a skill not kept")
	app.profile.vault[str(known.skill)] = kept

# --- the menu ----------------------------------------------------------------------------------

func _menu(app: Control) -> void:
	for in_run in [false, true]:
		app.menu.open(app.settings, {"in_run": in_run, "host": true, "solo": false, "phase": "tunnels", "depth": 12, "mine": "The Quarry"})
		for page in ["main", "settings", "controls", "abandon", "leave", "quit", "invite"]:
			app.menu._show(page)
			await _fits(app.menu, "the menu's %s page" % page)
		app.menu.close()

# --- the close look ----------------------------------------------------------------------------

func _inspector() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mine: Dictionary = DeepContent.mine(DeepContent.starter_mine())
	var inclusions: Array = DeepContent.section("inclusions").keys()
	## Every skill, riddled with the wordiest inclusions and Flawless, raw and appraised.
	inclusions.sort_custom(func(a: String, b: String) -> bool: return str(DeepContent.inclusion(a).get("text", "")).length() > str(DeepContent.inclusion(b).get("text", "")).length())
	for skill in DeepContent.section("skills"):
		var stone: Dictionary = DeepForge.roll_stone(rng, mine, 12, 4, {"run": "fit", "source": "vein", "mine": DeepContent.starter_mine(), "depth": 12, "date": "2026-09-22"}, "fit_%s" % skill)
		stone.skill = str(skill)
		stone.appraised = true
		stone.inclusions_revealed = true
		stone.clarity = 0
		stone.inclusions = inclusions.slice(0, DeepStone.inclusion_slots(0))
		await _look("stone", stone, "the close look at a riddled %s" % str(skill))
		stone.clarity = 5
		stone.inclusions = []
		await _look("stone", stone, "the close look at a Flawless %s" % str(skill))
		stone.appraised = false
		stone.clarity = 0
		stone.inclusions = inclusions.slice(0, DeepStone.inclusion_slots(0))
		await _look("stone", stone, "the close look at a raw %s" % str(skill))
	for key in DeepContent.section("characters"):
		await _look("stone", DeepStone.birthstone(str(key)), "the close look at %s's Birthstone" % str(key))
		## The sheet a new lapidary is presented on: plate, Birthstone and everything said
		## about them, all of it on one page.
		var welcome: CanvasLayer = load("res://view/inspect/inspector.gd").new()
		screen.add_child(welcome)
		welcome.call("_frame", DeepUi.ACCENT, {"title": "A new lapidary", "subtitle": DeepContent.character_title(str(key)), "button": "Take them on"})
		welcome.call("_fill_lapidary", str(key), DeepUi.ACCENT)
		await _fits(welcome, "%s joining the workshop" % str(key))
		welcome.free()
	for key in DeepContent.section("dice"):
		var die: Dictionary = DeepDice.make(str(key), DeepContent.die(str(key)), "fit_%s" % key)
		await _look("die", die, "the close look at a %s" % str(key))
	for key in DeepContent.section("creatures"):
		var foe: Dictionary = DeepCreatures.make(str(key), "fit_%s" % key, 20, 4)
		foe.statuses = {"poison": 3, "stun": 1}
		foe.block = 9
		## Mid-fight: revealed dice, statuses and the complete moveset.
		foe.hand = [ {"value": 5, "key": "D6", "shape": "D6"}, {"value": 5, "key": "D6", "shape": "D6"}, {"value": 11, "key": "D12", "shape": "D12"}]
		foe.moves = DeepCreatures.moves_for(foe)
		await _look("creature", foe, "the close look at a %s" % str(key))

func _enemy_panels() -> void:
	var panel: Control = load("res://view/battle/enemy_panel.gd").new()
	screen.add_child(panel)
	for key in DeepContent.section("creatures"):
		for health in [100, 20]:
			var foe: Dictionary = DeepCreatures.make(str(key), "panel_" + str(key), 20, 4)
			foe.hp = maxi(1, int(foe.max_hp) * health / 100)
			DeepCreatures.prepare(foe)
			for acting in [false, true]:
				foe.acting = acting
				panel.show_enemy(foe, health, true)
				panel.position = Vector2(100, 82)
				await _fits(panel, "%s moveset at %d%% HP (%s)" % [str(key), health, "acting" if acting else "planning"])
				check(panel.size.y < 460 and panel.size.x < 550, "moveset leaves room for the battle and dock")
	panel.free()

func _look(kind: String, item: Dictionary, what: String) -> void:
	## The inspector will not open without a display; the sheet is built by hand instead.
	for fanfare in [ {}, {"title": "Appraised", "subtitle": "A long line under the title, the way a won stone is announced", "button": "Into the bag"}]:
		if kind != "stone" and not fanfare.is_empty():
			continue
		var sheet: CanvasLayer = load("res://view/inspect/inspector.gd").new()
		screen.add_child(sheet)
		sheet.call("_frame", DeepUi.ACCENT, fanfare)
		match kind:
			"stone":
				if DeepStone.is_birthstone(item):
					sheet.call("_fill_birthstone", item)
				else:
					sheet.call("_fill_stone", item, {})
			"die": sheet.call("_fill_die", item, {"roll": {"value": 3, "face": 2, "kind": "plain", "rerolls": 2}})
			"creature": sheet.call("_fill_creature", item, {}, {})
		for page in sheet.call("page_names"):
			sheet.call("show_page", page)
			await _fits(sheet, "%s%s, page '%s'" % [what, " (won)" if not fanfare.is_empty() else "", str(page)])
		sheet.free()

# --- the appraisal -----------------------------------------------------------------------------

func _appraisals(app: Control) -> void:
	## The appraisal once it has all been read: the wordiest stone there can be, weighed
	## against the wordiest kept one, with every choice a player could be offered.
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var mine: Dictionary = DeepContent.mine(DeepContent.starter_mine())
	var inclusions: Array = DeepContent.section("inclusions").keys()
	inclusions.sort_custom(func(a: String, b: String) -> bool: return str(DeepContent.inclusion(a).get("text", "")).length() > str(DeepContent.inclusion(b).get("text", "")).length())
	var skills: Array = DeepContent.section("skills").keys()
	skills.sort_custom(func(a: String, b: String) -> bool: return str(DeepContent.skill(a).get("text", "")).length() > str(DeepContent.skill(b).get("text", "")).length())
	var raw: Dictionary = DeepForge.roll_stone(rng, mine, 20, 6, {"run": "fit", "source": "vein"}, "fit_appraise")
	raw.skill = str(skills[0])
	var riddled: Dictionary = raw.duplicate(true)
	riddled.clarity = 0
	riddled.carat = 20
	riddled.inclusions = inclusions.slice(0, DeepStone.inclusion_slots(0))
	var clear: Dictionary = raw.duplicate(true)
	clear.clarity = 5
	clear.inclusions = []
	var kept: Dictionary = riddled.duplicate(true)
	kept.appraised = true
	kept.id = "fit_kept"
	var home_actions: Array = app.home._tray_actions(kept, true)
	var run_actions: Array = [ {"label": "Set in socket 6", "glyph": "gem", "caption": "Into the rail for the next fight"},
		{"label": "Into the bag", "glyph": "bag", "caption": "Set it from the bench any time", "dismiss": true},
		{"label": "Sell for 9999 pyrite", "glyph": "scales", "caption": "Half its worth, on the scales"}]
	for found in [riddled, clear]:
		for owned in [ {}, kept]:
			for list in [home_actions, run_actions]:
				var sheet: CanvasLayer = load("res://view/gems/appraisal.gd").new()
				screen.add_child(sheet)
				sheet.call("build", found, {"owned": owned, "actions": list})
				sheet.call("finish")
				var what: String = "the appraisal of a %s stone%s, %s" % ["riddled" if found == riddled else "flawless", " weighed against a kept one" if not owned.is_empty() else "", "at home" if list == home_actions else "down the mine"]
				await _fits(sheet, what)
				check(sheet.get("_choices").visible and not sheet.get("_skip").visible, "%s ends on its choices" % what)
				sheet.free()

# --- the run ------------------------------------------------------------------------------------

func _run(app: Control) -> void:
	app._depart(9001)
	await process_frame
	var descent: Control = app.descent
	var run: Dictionary = app.session.run
	var me: Dictionary = app.session.local_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mine: Dictionary = DeepContent.mine(DeepContent.starter_mine())
	## The shaft head: the stakes, and a pick taken.
	descent.show_state(run)
	await _fits(screen, "the grubstake")
	var head_state: Dictionary = run.duplicate(true)
	var picks: Array = []
	for index in range(3):
		var candidate: Dictionary = DeepForge.roll_stone(rng, mine, 8, 6, {}, "fit_pick%d" % index)
		candidate.appraised = true
		candidate.clarity = 0
		candidate.inclusions = DeepContent.section("inclusions").keys().slice(0, 3)
		candidate.inclusions_revealed = true
		picks.append(candidate)
	head_state.grubstake.offers[app.session.local_id] = [ {"id": "fit_pick", "kind": "stone", "boons": ["REWARD_STONE", "COST_WOUND"], "needs": ["pick"], "pick_kind": "stone", "picks": picks}]
	descent._stake_choosing = "fit_pick"
	descent.show_state(head_state)
	await _fits(screen, "a pick stake's three stones")
	descent._stake_choosing = ""
	## A heavy haul: raw and appraised stones in every color.
	for i in range(36):
		var found: Dictionary = DeepForge.roll_stone(rng, mine, 6 + i % 12, 3, {"run": "fit", "source": "vein"}, "fit_haul%d" % i)
		if i % 2 == 0:
			found.appraised = true
			found.inclusions_revealed = true
		me.haul.append(found)
	for which in ["gems", "dice"]:
		descent.open_bench(which)
		await _fits(screen, "the bench's %s tab" % which)
		for stone in me.haul.slice(0, 2):
			descent._bench._pick = str(stone.id) if which == "gems" else str(me.dice[0].id)
			descent._bench._render()
			await _fits(screen, "the bench's %s tab with something under the lamp" % which)
	descent._bench._pick = ""
	descent._bench._haul_page = 1
	descent.open_bench("gems")
	await _fits(screen, "the bench's second page of the haul")
	descent._bench.close()
	## Every oddity, smithy and carver: its card along the bottom of its room.
	var room: Dictionary = run.duplicate(true)
	room.phase = "chamber"
	me.ore = 140
	for key in DeepContent.section("oddities"):
		room.chamber = {"kind": "oddity", "oddity": str(key), "results": {}, "depth": 1, "settled": false}
		for kind in DeepDescent.CARD_ROOMS:
			if DeepDescent.room_card(kind) == str(key):
				room.chamber.kind = kind
		descent.show_state(room)
		await _fits(screen, "the %s's card" % str(key))
		## And the second page of every piece of work on it: the thing to work on laid out
		## in full, with what it cannot be done to greyed out.
		for choice in DeepContent.oddity(str(key)).get("choices", []):
			if str(choice.get("needs", "")).is_empty():
				continue
			descent._oddity_step = str(choice.id)
			descent.show_state(room)
			await _fits(screen, "choosing what to %s at the %s" % [str(choice.get("label", choice.id)).to_lower(), str(key)])
		descent._oddity_step = ""
	## The tray that takes the dock's place while one of the party's own things is chosen.
	for offered in [["die", me.dice], ["stone", me.haul.slice(0, 6)]]:
		descent._run_dock.offer(str(offered[0]), offered[1], "Which one?")
		descent.show_state(room)
		await _fits(screen, "the dock giving way to the %s, large, for one to be chosen" % str(offered[0]))
		descent._run_dock.cancel_offer()
	descent.show_state(room)
	## What a motherlode gives up, what an oddity made, and what a stake did.
	var rewards: Dictionary = {"ore": 44, "stones": me.haul.slice(0, 4), "dice": me.dice.slice(0, 2)}
	descent._hold_page("spoils", {"title": "A motherlode", "glyph": "gem", "subtitle": "The rock gives up everything it had", "rewards": rewards})
	descent.show_state(run)
	await _fits(screen, "the spoils of a motherlode")
	descent._hold_page("oddity", {"oddity": str(DeepContent.section("oddities").keys()[0]), "room": "oddity",
		"result": {"message": "A long message about what the oddity did to you and your stones, and your dice as well.", "made": me.haul.slice(0, 3), "dice": me.dice.slice(0, 2), "lost": me.haul.slice(3, 5)}})
	descent.show_state(run)
	await _fits(screen, "what an oddity did")
	descent._hold_page("stake", {"result": {"boons": ["COST_CHIPPED", "REWARD_CARATS"], "message": "Strike is now judged Rough. Strike weighs 9 carats now.",
		"made": me.haul.slice(0, 2), "dice": me.dice.slice(0, 2), "changed": me.haul.slice(2, 3)}})
	descent.show_state(run)
	await _fits(screen, "what a stake did")
	descent._hold = {}
	## A fall with the haul still in hand: every stone rolls.
	var fallen: Dictionary = run.duplicate(true)
	fallen.phase = "salvage"
	var rolls: Array = []
	for stone in me.haul:
		rolls.append({"stone": stone, "sides": 6, "roll": 6 if rolls.size() % 3 == 0 else 2, "kept": rolls.size() % 3 == 0, "tier": "FINE"})
	fallen.salvage = {}
	fallen.salvage[app.session.local_id] = {"rolls": rolls}
	descent._salvage_thrown = true
	for page in range(2):
		descent._pages["salvage"] = page
		descent.show_state(fallen)
		await _fits(screen, "page %d of the salvage of a heavy haul" % page)
	## The end of the run, with the whole haul coming home.
	var over: Dictionary = run.duplicate(true)
	over.phase = "over"
	over.outcome = "extracted"
	descent._end_shown = true
	for page in range(2):
		descent._pages["home"] = page
		descent.show_state(over)
		await _fits(screen, "page %d of the end of a run with a heavy haul" % page)
	descent._end_shown = false
	descent._pages = {}
	## A fight, planning, with every chip on show.
	var guard: int = 0
	while guard < 400 and not (DeepDescent.in_battle(app.session.run) and str(DeepDescent.battle(app.session.run).phase) == "planning"):
		guard += 1
		_advance(app)
	check(DeepDescent.in_battle(app.session.run), "the run reaches a fight")
	if DeepDescent.in_battle(app.session.run):
		var fight: Dictionary = DeepDescent.battle(app.session.run)
		var unit: Dictionary = DeepBattle.player(fight, app.session.local_id)
		unit.statuses = {"poison": 3, "curse": 25}
		unit.block = 6
		unit.buried = [1]
		unit.granted_rerolls = 1
		unit.sparkle = 3
		unit.run_mods = {"shrine": "pair"}
		for foe in fight.enemies:
			foe.statuses = {"poison": 2, "stun": 1}
			foe.block = 4
			foe.stolen_gold = 3
		descent.show_state(app.session.run)
		await _fits(screen, "a fight with every chip on show")

func _advance(app: Control) -> void:
	## One step of a run toward its next fight, taking the first of whatever is offered.
	var run: Dictionary = app.session.run
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
				app.session.tick(0.5)
			elif str(run.chamber.kind) in ["vein", "vug"]:
				var unit: Dictionary = app.session.local_player()
				var open_spot: int = -1
				for spot in run.chamber.vein.spots:
					if str(spot.taken).is_empty():
						open_spot = int(spot.index)
						break
				var can_swing: bool = int(unit.hp) > DeepDescent.strike_cost(int(unit.get("strikes", 0)), bool(run.chamber.vein.get("hazard", false)))
				if open_spot >= 0 and can_swing and bool(unit.get("mining", false)):
					app.session.send({"kind": "strike", "spot": open_spot})
				else:
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

# --- the check ----------------------------------------------------------------------------------

func _fits(node: Node, what: String) -> void:
	## Twice round the loop, so every container has sorted its children.
	await process_frame
	await process_frame
	var found: Array = []
	_scan(node, Rect2(Vector2.ZERO, CANVAS), found)
	check(found.is_empty(), "%s fits on one page: %s" % [what, "; ".join(found.slice(0, 4))])

func _scan(node: Node, bounds: Rect2, found: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is ScrollContainer:
		## One page is allowed to scroll and says so on the node itself: the vault, which
		## holds every skill in the pack and would have to shrink its stones to a smudge to
		## keep up with it. The scroller has to lie inside the page like anything else;
		## what it holds does not, because being taller than its window is the point of it.
		if not bool(node.get_meta("may_scroll", false)):
			found.append("%s scrolls" % _name(node))
			return
		var box := node as Control
		var window: Rect2 = box.get_global_rect()
		if window.size.x > 0.5 and window.size.y > 0.5 and not bounds.grow(1.5).encloses(window):
			found.append("%s at %s runs past %s" % [_name(box), _rect(window), _rect(bounds)])
		return
	var inner: Rect2 = bounds
	## Only what containers lay out is content. Glows, halos and backdrops placed by hand may
	## spill past the edge on purpose; the containers they decorate may not.
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

func _name(node: Node) -> String:
	var parts: Array = []
	var at: Node = node
	while at != null and at != screen and parts.size() < 4:
		var label: String = at.get_class()
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
	## As much as a player can have: every lapidary, a stone for every skill, a full tray, a
	## long ledger.
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
			profile.bowl.append(DeepDice.make(str(key), DeepContent.die(str(key)), "fit_bowl_%s_%d" % [key, copy]))
	profile.gold = 123456
	for i in range(40):
		profile.history.append({"date": "2026-08-%02d" % (1 + i % 28), "mine": DeepContent.starter_mine(), "depth": 4 + i % 20, "outcome": ["extracted", "fallen", "conquered"][i % 3], "stones": i % 9})
	profile.records.runs = 40

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
