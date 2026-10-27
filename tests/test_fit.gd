extends SceneTree
## Every screen fits on the smallest canvas the game draws on (1600 × 900; a window of
## any other shape only adds room). Only the vault, the bestiary's list and long gem rails
## may scroll.
## Each screen is filled as full as a player can make it (a vault of every skill, a bowl of
## every lapidary's dice, a long ledger, a heavy haul) and every control on it must lie
## inside the screen and inside anything that clips it.

const CANVAS := Vector2i(1600, 900)
const Homecoming = preload("res://view/home/homecoming.gd")
const DescentScreen = preload("res://view/run/descent_screen.gd")
const MarketPage = preload("res://view/home/market_page.gd")
const DiceIcons = preload("res://view/dice/dice_icons.gd")

var checks: int = 0
var failures: Array = []
## The screen everything is drawn into. Headless, the window has no real size, so the game
## gets a viewport of its own at exactly the smallest canvas.
var screen: SubViewport

func _init() -> void:
	## Drawn the way the smallest window draws it (1024 × 640, 0.64 of the canvas): the floor
	## on text is at its highest and small text is set in SemiBold, so pages are at their widest.
	DeepUi.text_scale = 0.64
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
	## Large text (Settings > Comfort) on the largest window sets no text bigger than this run
	## already draws every page at.
	var floor_here: int = DeepUi.min_text()
	DeepUi.text_scale = 2.0
	DeepUi.text_large = true
	check(DeepUi.min_text() <= floor_here, "large text stays at or under the floor every page is fitted at (%d, got %d)" % [floor_here, DeepUi.min_text()])
	DeepUi.text_large = false
	DeepUi.text_scale = 0.64
	_fill(app.profile)
	app._profile_changed()
	await _workshop(app)
	await _menu(app)
	await _inspector()
	await _enemy_panels()
	await _appraisals(app)
	await _run(app)
	await _void_views(app)
	await _die_plates()
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
		lobby.members[id] = {"name": "Guest With A Long Name %d" % i, "character": "VESPER", "ready": i % 2 == 0, "connected": true,
			"showcase": app.profile.vault.values().slice(0, 7)}
	home.refresh(app.profile, lobby, "hosting", true, app.session.local_id, false, app.settings, "109775241234567890")
	var player_name: String = str(app.profile.name)
	app._rename_player("W".repeat(DeepProfile.NAME_LIMIT))
	await _fits(screen, "the workshop with a long player name")
	## The player's chip opens their profile, where the name is changed.
	home._bar.get_node("PlayerName").pressed.emit()
	check(home.tab == "profile", "the player's chip opens the profile page")
	await _fits(screen, "the profile page with a long player name")
	var rename: Node = home.find_child("Rename", true, false)
	check(rename is Button, "the profile page offers to change the name")
	if rename is Button:
		(rename as Button).pressed.emit()
		await _fits(app.menu, "the player name editor")
		app.menu.close()
	app._rename_player(player_name)
	home.refresh(app.profile, lobby, "hosting", true, app.session.local_id, false, app.settings, "109775241234567890")
	for tab in ["descend", "delvers", "vault", "market", "bestiary", "profile"]:
		home.open(tab)
		await _fits(screen, "the %s tab" % tab)
	await _bestiary(app)
	## Every page of the profile's runs.
	for page in range(3):
		home._pages["ledger"] = page
		home.open("profile", true)
		await _fits(screen, "page %d of the profile's runs" % page)
	home._pages["ledger"] = 0
	## Descend as the host and as a guest, with the party open and a guest's showcase shown.
	for host in [true, false]:
		home.refresh(app.profile, lobby, "hosting" if host else "joined", host, app.session.local_id if host else "p1", false, app.settings, "109775241234567890")
		for party in ["", "open", "p2"]:
			home._party_open = not party.is_empty()
			home._showcase_of = party if party.begins_with("p") else ""
			home.open("descend")
			await _fits(screen, "Descend%s%s" % ["" if party.is_empty() else (" with the party open" if party == "open" else " with a guest's showcase"), "" if host else " for a guest"])
	home._party_open = false
	home._showcase_of = ""
	home.refresh(app.profile, lobby, "hosting", true, app.session.local_id, false, app.settings, "109775241234567890")
	await _daily_map(app, lobby)
	await _market(app)
	## Every delver's dossier and sockets, with a socket picked.
	for key in DeepContent.characters_in_unlock_order():
		for view in ["dossier", "sockets"]:
			for picked in [-1, 0]:
				home._roster_pick = str(key)
				home._roster_view = view
				home._bench_socket = picked
				home.open("delvers", true)
				await _fits(screen, "the Delvers tab on %s's %s%s" % [str(key), view, " with one picked" if picked >= 0 else ""])
	## Every page of the sockets' stone picker, as tiles and as a list.
	for layout in ["grid", "list"]:
		load("res://view/home/stone_browser.gd").settings(home, "sockets").layout = layout
		for page in range(3):
			home._pages["sockets_page"] = page
			home._roster_view = "sockets"
			home._bench_socket = 0
			home.open("delvers", true)
			await _fits(screen, "page %d of the sockets' stones as a %s" % [page, layout])
	load("res://view/home/stone_browser.gd").settings(home, "sockets").layout = "grid"
	home._pages["sockets_page"] = 0
	home._bench_socket = -1
	## A delver with every socket bought, and one with the next for sale.
	for open in [3, 6]:
		app.profile.characters.FLORIN.sockets = open
		home._roster_pick = "FLORIN"
		home._roster_view = "sockets"
		home.open("delvers", true)
		await _fits(screen, "Florin's sockets with %d open" % open)
	app.profile.characters.FLORIN.sockets = 3
	home._roster_pick = ""
	home._roster_view = "dossier"
	## The way down to a deeper mine, insured, with guests who cannot pay their fare.
	app.profile.mines.SEEPS.unlocked = true
	app.profile.outfit.insure = true
	lobby.mine = "SEEPS"
	for host in [true, false]:
		home.refresh(app.profile, lobby, "hosting" if host else "joined", host, app.session.local_id if host else "p1", false, app.settings, "109775241234567890")
		for party in [false, true]:
			home._party_open = party
			home.open("descend")
			await _fits(screen, "Descend into the Seeps, insured, with the party short%s%s" % [" and open" if party else "", "" if host else ", as a guest"])
	home._party_open = false
	app.profile.outfit.insure = false
	lobby.mine = DeepContent.starter_mine()
	home.refresh(app.profile, lobby, "hosting", true, app.session.local_id, false, app.settings, "109775241234567890")
	## Commissions: one a stone on the tray can fill, one filled, one open.
	var wanted: Dictionary = {}
	for stone in app.profile.tray:
		if bool(stone.get("appraised", false)):
			wanted = stone
	var commissions: Array = app.profile.daily.commissions
	check(commissions.size() == 3, "the workshop opens on three commissions")
	commissions[0] = {"id": "fit_ready", "skill": str(wanted.skill), "need": {"kind": "pure", "value": 0}, "reward": 99999, "done": false}
	commissions[1] = commissions[1].duplicate()
	commissions[1].done = true
	commissions[1].paid = 12345
	home._market_view = "main"
	home.open("market", true)
	await _fits(screen, "the Market with commissions ready and filled")
	## The tray stone a commission wants: Turn it in beside keeping either stone.
	check(Homecoming.actions(home, wanted).any(func(a: Dictionary) -> bool: return str(a.label) == "Turn it in"), "a stone a commission wants can be turned in")
	home._vault_view = "unappraised"
	home._appraise_pick = str(wanted.id)
	home.open("vault", true)
	await _fits(screen, "the Unappraised view weighing a stone a commission wants")
	## And the first stone of its skill, wanted by a commission: keep it, or turn it in.
	var rival: Dictionary = app.profile.vault.get(str(wanted.skill), {})
	app.profile.vault.erase(str(wanted.skill))
	check(not Homecoming.actions(home, wanted).any(func(a: Dictionary) -> bool: return str(a.label).begins_with("Keep it, replace")), "a first stone of its skill is never offered for sale")
	home.open("vault", true)
	await _fits(screen, "the Unappraised view on a new skill a commission wants")
	app.profile.vault[str(wanted.skill)] = rival
	## The vault, each color, as tiles and as a list, with a stone under the lamp.
	home._vault_view = "collection"
	home._vault_pick = str(app.profile.vault.keys()[0])
	var vault_settings: Dictionary = load("res://view/home/stone_browser.gd").settings(home, "vault")
	for layout in ["grid", "list"]:
		vault_settings.layout = layout
		for color in [""] + home.color_ORDER:
			vault_settings.colors = [] if color.is_empty() else [color]
			home.open("vault", true)
			await _fits(screen, "the vault as a %s filtered to '%s'" % [layout, color])
	vault_settings.colors = []
	vault_settings.layout = "grid"
	## The tray, raw and appraised, and every page of it, coming home and in the vault. Two Geodes
	## are on it too: the bench shows each as a rock to crack, not a stone to read.
	var sealed_rng := RandomNumberGenerator.new()
	sealed_rng.seed = 31
	for i in range(2):
		app.profile.tray.append(DeepEconomy.roll_run_geode(sealed_rng, "QUARRY" if i == 0 else "GEODE", {"run": "fit"}, "fit_geode%d" % i))
	for coming_home in [true, false]:
		app.profile.homecoming = coming_home
		home._vault_view = "unappraised"
		for stone in app.profile.tray:
			home._appraise_pick = str(stone.id)
			home.open("descend" if coming_home else "vault", true)
			await _fits(screen, "%s on %s" % ["coming home" if coming_home else "the Unappraised view", DeepUi.stone_name(stone)])
		for page in range(3):
			home._pages["tray"] = page
			home.open("descend" if coming_home else "vault", true)
			await _fits(screen, "page %d of the tray%s" % [page, ", coming home" if coming_home else ""])
		home._pages["tray"] = 0
	app.profile.tray = app.profile.tray.filter(func(s: Dictionary) -> bool: return not DeepStone.is_geode(s))
	app.profile.homecoming = false
	## A known stone whose skill is not kept yet: keep or sell, nothing to weigh it against.
	var known: Dictionary = {}
	for stone in app.profile.tray:
		if bool(stone.get("appraised", false)):
			known = stone
	var kept: Dictionary = app.profile.vault.get(str(known.skill), {})
	app.profile.vault.erase(str(known.skill))
	home._appraise_pick = str(known.id)
	home._vault_view = "unappraised"
	home.open("vault", true)
	await _fits(screen, "the Unappraised view on a stone of a skill not kept")
	app.profile.vault[str(known.skill)] = kept
	home._vault_view = "collection"
	## The tray's last card coming home, with more stones kept than it shows.
	var waiting: Array = app.profile.tray
	app.profile.tray = []
	app.profile.homecoming = true
	var came: Array = []
	for stone in app.profile.vault.values().slice(0, 6):
		came.append({"stone": stone, "was": {} if came.size() % 2 == 0 else stone})
	home.set_meta("came_kept", came)
	home.open("descend", true)
	await _fits(screen, "the tray's last card, coming home with six stones kept")
	home.remove_meta("came_kept")
	app.profile.homecoming = false
	app.profile.tray = waiting

func _daily_map(app: Control, lobby: Dictionary) -> void:
	## The day's seam on Descend, chosen for the party, as the host and as a guest: before the
	## Quarry is beaten, not dug yet today, and dug.
	var home: Control = app.home
	var starter: Dictionary = app.profile.mines[DeepContent.starter_mine()]
	var beaten: bool = bool(starter.get("boss", false))
	lobby.daily = DeepEconomy.today()
	for state in ["locked", "fresh", "played"]:
		starter.boss = state != "locked"
		app.profile.dig = {"date": DeepEconomy.today(), "run_id": "fit", "best_score": 999999, "best_gold": 99999, "runs": 99} if state == "played" else {}
		for host in [true, false]:
			home.refresh(app.profile, lobby, "hosting" if host else "joined", host, app.session.local_id if host else "p1", false, app.settings, "109775241234567890")
			home.open("descend")
			await _fits(screen, "the daily dig, %s%s" % [state, "" if host else ", as a guest"])
	lobby.daily = ""
	app.profile.dig = {}
	starter.boss = beaten
	home.refresh(app.profile, lobby, "hosting", true, app.session.local_id, false, app.settings, "109775241234567890")

func _market(app: Control) -> void:
	## The Market: the counter fresh, a Geode opened, the case sold
	## out and the day restocked; the Wheel and the Oven with nothing and something picked; the
	## contract bench empty, with five of one grade on it (the vault's among them, asking
	## twice), and every page of its stones. Then a Geode cracked and a contract sealed, each
	## read to the end with its choices.
	var home: Control = app.home
	home._market_view = "main"
	home.open("market", true)
	await _fits(screen, "the Market")
	## The case at its wordiest: heavy stones of the longest rules, three inclusions each, whose
	## lines take what room the cards have left and no more.
	var stocked: Array = app.profile.daily.get("case", [])
	var wordy: Array = []
	for spec in [["PROCESSION", ["FRACTURE", "FEATHER", "KNOT"]], ["SPECTRUM", ["VEIL", "BRUISE", "CAVITY"]], ["QUINTESSENCE", ["FLUORESCENCE", "HALO", "GLINT"]]]:
		var heavy: Dictionary = DeepStone.make(str(spec[0]), 24, 4, 0, spec[1], {"source": "vein"}, "fit_%s" % str(spec[0]).to_lower())
		heavy.appraised = true
		wordy.append({"id": "fit_case_%d" % wordy.size(), "stone": heavy, "price": DeepEconomy.case_price(heavy), "bought": false})
	app.profile.daily.case = wordy
	home.open("market", true)
	## The lines are handed out two frames after the case is laid out, and laid out again after.
	for _i in range(4):
		await process_frame
	await _fits(screen, "the Market with the wordiest case")
	app.profile.daily.case = stocked
	var shelf: Array = DeepEconomy.shelf(app.profile)
	check(shelf.size() == 2, "the Market opens on today's Geode and the week's")
	var opened: Dictionary = DeepEconomy.open_geode(app.profile, str(shelf[0].get("id", ""))) if not shelf.is_empty() else {}
	check(bool(opened.get("ok", false)), "a Geode can be bought from the full workshop")
	for entry in DeepEconomy.case_stones(app.profile):
		entry.bought = true
	check(bool(DeepEconomy.restock(app.profile).get("ok", false)) or DeepEconomy.restocked_today(app.profile), "the Market can be restocked")
	for entry in DeepEconomy.case_stones(app.profile):
		entry.bought = true
	home.open("market", true)
	await _fits(screen, "the Market with a Geode opened, the case sold out and the day restocked")
	for kind in ["wheel", "oven"]:
		for pick in ["", str(app.profile.vault.keys()[0])]:
			home._market_view = kind
			home._rework_pick = pick
			home.open("market", true)
			await _fits(screen, "the %s%s" % [kind, " with a stone picked" if not pick.is_empty() else ""])
		## Just reworked: the result kept under the ladder, the Oven naming three things inside.
		var worked: String = str(app.profile.vault.keys()[0])
		var field: String = "cut" if kind == "wheel" else "clarity"
		var was_used: bool = DeepEconomy.rework_used(app.profile, field)
		var before: Dictionary = DeepProfile.owned(app.profile, worked).duplicate(true)
		var inside: Array = before.get("inclusions", []).duplicate()
		app.profile.vault[worked].inclusions = ["FLUORESCENCE", "ALEXANDRITE", "FRACTURE"]
		app.profile.daily["rework_" + field] = true
		home._market_view = kind
		home._rework_pick = worked
		home._rework_done = {"kind": field, "skill": worked, "before": before, "now": 0, "broke": false}
		home.open("market", true)
		await _fits(screen, "the %s just after a rework, its result kept" % kind)
		check(home.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.begins_with("Worth ")), "the %s keeps what the rework did to the stone's worth" % kind)
		app.profile.vault[worked].inclusions = inside
		app.profile.daily["rework_" + field] = was_used
		home._rework_done = {}
		for page in range(3):
			home._pages["bench_page"] = page
			home.open("market", true)
			await _fits(screen, "page %d of the %s's stones" % [page, kind])
		home._pages["bench_page"] = 0
	home._rework_pick = ""
	home._market_view = "contract"
	home._contract = []
	home.open("market", true)
	await _fits(screen, "the contract bench, empty")
	var by_tier: Dictionary = {}
	for entry in DeepEconomy.contract_stones(app.profile):
		var tier: String = str(DeepStone.grade(entry.stone).tier)
		if not by_tier.has(tier):
			by_tier[tier] = []
		by_tier[tier].append(str(entry.ref))
	var five: Array = []
	for tier in by_tier:
		if five.is_empty() and by_tier[tier].size() >= DeepEconomy.contract_size():
			five = by_tier[tier].slice(0, DeepEconomy.contract_size())
	check(five.size() == DeepEconomy.contract_size(), "the full workshop has five stones of one grade for a contract")
	home._contract = five
	for sure in [false, true]:
		home._contract_sure = sure
		home.open("market", true)
		await _fits(screen, "the contract bench with five on it%s" % (", asking twice" if sure else ""))
	for from in ["all", "tray", "vault"]:
		home._contract_from = from
		for page in range(3):
			home._pages["contract"] = page
			home.open("market", true)
			await _fits(screen, "page %d of the contract bench's stones (%s)" % [page, from])
	home._contract_from = "all"
	home._pages["contract"] = 0
	home._contract = []
	home._contract_sure = false
	home._market_view = "main"
	## The overlays, finished: the wordiest stone the tray has, every choice there is.
	var made: Dictionary = {}
	for stone in app.profile.tray:
		if bool(stone.get("appraised", false)) and str(DeepContent.skill(str(stone.skill)).get("text", "")).length() > str(DeepContent.skill(str(made.get("skill", ""))).get("text", "")).length():
			made = stone
	var inputs: Array = []
	for ref in five:
		inputs.append(DeepEconomy.contract_input(app.profile, str(ref)).stone)
	var actions: Array = MarketPage.found_actions(home, made)
	actions = actions.slice(0, 1) + [ {"label": "Turn it in", "glyph": "flag", "caption": "A commission pays 99999 gold for it"}] + actions.slice(1)
	for kind in ["geode", "contract"]:
		for fresh in [true, false]:
			var sheet: CanvasLayer = load("res://view/gems/geode.gd").new()
			screen.add_child(sheet)
			sheet.call("build", kind, shelf[1] if kind == "geode" else {}, inputs if kind == "contract" else [], made,
				{"owned": {} if fresh else app.profile.vault.get(str(made.skill), {}), "actions": actions, "new_skill": fresh, "wanted": "" if fresh else "A commission wants this stone: 99999 gold"})
			var what: String = "%s read to the end%s" % ["a Geode cracked" if kind == "geode" else "a contract sealed", ", a new skill" if fresh else ", weighed against a kept one"]
			await _fits(sheet, what + " before it is played")
			sheet.call("finish")
			await _fits(sheet, what)
			check(sheet.get("_choices").visible and not sheet.get("_skip").visible, "%s ends on its choices" % what)
			sheet.free()

# --- the menu ----------------------------------------------------------------------------------

func _menu(app: Control) -> void:
	for in_run in [false, true]:
		app.menu.open(app.settings, {"in_run": in_run, "host": true, "solo": false, "phase": "tunnels", "depth": 12, "mine": "The Quarry"})
		for page in ["main", "settings", "soundtrack", "controls", "abandon", "leave", "quit", "invite"]:
			app.menu._show(page)
			await _fits(app.menu, "the menu's %s page" % page)
		app.menu.close()
	## The host of a party run: who is away, and the line they come back on, in each state.
	for party in [ {"status": "local", "away": ["Guest With A Long Name 1", "Guest With A Long Name 2", "Guest With A Long Name 3"]},
			{"status": "opening", "away": ["Bo"]}, {"status": "hosting", "invite_code": "109775241234567890", "away": ["Bo"]},
			{"status": "hosting", "lan": "192.168.100.200", "away": []}]:
		app.menu.open(app.settings, {"in_run": true, "host": true, "solo": party.status == "local", "phase": "tunnels", "depth": 12, "mine": "The Quarry", "party": party})
		await _fits(app.menu, "the menu with the party %s" % str(party.status))
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
		welcome.call("_frame", DeepUi.ACCENT, {"title": "A new delver", "subtitle": DeepContent.character_title(str(key)), "button": "Take them on"})
		welcome.call("_fill_lapidary", str(key), DeepUi.ACCENT)
		await _fits(welcome, "%s joining the workshop" % str(key))
		welcome.free()
	for key in DeepContent.section("dice"):
		var die: Dictionary = DeepDice.make(str(key), "fit_%s" % key)
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
				panel.show_enemy(foe, health)
				panel.position = Vector2(100, 82)
				await _fits(panel, "%s moveset at %d%% HP (%s)" % [str(key), health, "acting" if acting else "planning"])
				check(panel.size.y < 460 and panel.size.x < 550, "%s moveset leaves room for the battle and dock: %s" % [str(key), str(panel.size)])
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
	var home_actions: Array = Homecoming.actions(app.home, kept)
	var run_actions: Array = [ {"label": "Set in socket 6", "glyph": "gem", "caption": "Into the rail for the next fight"},
		{"label": "Into the bag", "glyph": "bag", "caption": "Set it from the bench any time", "dismiss": true},
		{"label": "Sell for 9999 pyrite", "glyph": "scales", "caption": "Half its worth, on the scales"}]
	## Every choice at home at once: both keeps, a commission's Turn in.
	home_actions = home_actions.slice(0, 2) + [ {"label": "Turn it in", "glyph": "flag", "caption": "A commission pays 99999 gold for it"}] + home_actions.slice(2)
	for found in [riddled, clear]:
		for owned in [ {}, kept]:
			for list in [home_actions, run_actions]:
				var sheet: CanvasLayer = load("res://view/gems/appraisal.gd").new()
				screen.add_child(sheet)
				sheet.call("build", found, {"owned": owned, "actions": list, "new_skill": owned.is_empty() and list == home_actions})
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
	## The day's seam at the shaft head, first dug, beaten before and not paid, with its
	## wordiest cards of every kind, and a full party along the strip.
	var wordiest := func(kind: String) -> String:
		var keys: Array = DeepEconomy.daily_modifiers(kind)
		keys.sort_custom(func(a: String, b: String) -> bool: return str(DeepContent.entry("daily_modifiers", a).get("name", "")).length() > str(DeepContent.entry("daily_modifiers", b).get("name", "")).length())
		return str(keys[0])
	var seam: Dictionary = {"date": DeepEconomy.today(), "rail": wordiest.call("rail"), "mods": [wordiest.call("hazard"), wordiest.call("blessing"), "BORROWED_BIRTHSTONE"],
		"birthstone": "FLORIN"}
	var standings: Array = [ {"eligible": true, "best_score": 0, "best_gold": 0}, {"eligible": true, "best_score": 999999, "best_gold": 99999}, {"eligible": false, "best_score": 0, "best_gold": 0}]
	var daily_state: Dictionary = run.duplicate(true)
	daily_state.daily = seam
	for i in range(1, 4):
		var other: Dictionary = DeepDescent.player(daily_state, app.session.local_id).duplicate(true)
		other.id = "fit_p%d" % i
		other.name = "Guest With A Long Name %d" % i
		daily_state.players.append(other)
	for standing in standings:
		descent.daily_best = standing
		descent.show_state(daily_state)
		await _fits(screen, "the grubstake of the day's seam for a party of four, standing %s" % JSON.stringify(standing))
	descent.daily_best = {}
	descent.show_state(run)
	var head_state: Dictionary = run.duplicate(true)
	var picks: Array = []
	for index in range(3):
		var candidate: Dictionary = DeepForge.roll_stone(rng, mine, 8, 6, {}, "fit_pick%d" % index)
		candidate.appraised = true
		candidate.clarity = 0
		candidate.inclusions = DeepContent.section("inclusions").keys().slice(0, 3)
		candidate.inclusions_revealed = true
		picks.append(candidate)
	head_state.grubstake.offers[app.session.local_id] = [ {"id": "fit_pick", "kind": "stone", "boons": ["PICK_STONE", "COST_WOUND"], "needs": ["pick"], "pick_kind": "stone", "picks": picks}]
	descent._stake_choosing = "fit_pick"
	descent.show_state(head_state)
	await _fits(screen, "a pick stake's three stones")
	descent._stake_choosing = ""
	## Below the Quarry: a temporary stone for each of three locked sockets, one already set.
	var lent_state: Dictionary = run.duplicate(true)
	var lent_me: Dictionary = DeepDescent.player(lent_state, app.session.local_id)
	lent_me.temps = []
	for socket in range(3):
		var offered: Array = []
		for index in range(3):
			var candidate: Dictionary = picks[index].duplicate(true)
			candidate.id = "fit_lent%d_%d" % [socket, index]
			candidate.temporary = true
			candidate.fragile = true
			offered.append(candidate)
		lent_me.temps.append({"index": 2 + socket, "socket": "ANY", "picks": offered, "chosen": 1 if socket == 0 else -1})
	check(DeepDescent.temporary_left(lent_me) == 2, "two sockets still wait for their temporary stone")
	descent.show_state(lent_state)
	await _fits(screen, "the temporary stones for three locked sockets")
	await _above_dock(descent, "the temporary stones for three locked sockets")
	## A rail with nothing set at all: every one of six sockets waits, shown three at a time.
	for socket in range(3, 6):
		var offered: Array = []
		for index in range(3):
			var candidate: Dictionary = picks[index].duplicate(true)
			candidate.id = "fit_lent%d_%d" % [socket, index]
			candidate.temporary = true
			candidate.fragile = true
			offered.append(candidate)
		lent_me.temps.append({"index": socket - 3, "socket": "ANY", "picks": offered, "chosen": -1})
	check(DeepDescent.temporary_left(lent_me) == 5, "five sockets still wait for their temporary stone")
	descent.show_state(lent_state)
	await _fits(screen, "the temporary stones for six empty sockets")
	await _above_dock(descent, "the temporary stones for six empty sockets")
	## Then each die in the bowl is offered three to swap it for, one die at a time, at their
	## wordiest: a size off, a pattern, a material, an etching, and a face lost.
	for offer in lent_me.temps:
		offer.chosen = 0
	lent_me.dice_offers = []
	for index in range(lent_me.dice.size()):
		var original: Dictionary = lent_me.dice[index]
		DeepDice.etch(original, original.faces.size() - 1, "golden")
		var swaps: Array = []
		for step in [-1, 0, 3]:
			var offered: Dictionary = original.duplicate(true)
			if step != 0:
				DeepOddities.resize(offered, step)
			var stamped: Dictionary = DeepDice.make(str(offered.shape), str(offered.id), {"pattern": "split" if DeepDice.pattern_allows("split", str(offered.shape)) else "", "etches": DeepDice.etchings(offered)})
			offered.clear()
			offered.merge(stamped)
			offered.material = "cloud"
			DeepDice.etch(offered, 0, "exploding")
			swaps.append(offered)
		lent_me.dice_offers.append({"index": index, "die_id": str(original.id), "picks": swaps, "chosen": -1, "kept": index == 0})
	check(DeepDescent.dice_offers_left(lent_me) == lent_me.dice.size() - 1, "every die but the first still waits for its answer")
	descent.show_state(lent_state)
	await _fits(screen, "a die's three swaps at the shaft head")
	await _above_dock(descent, "a die's three swaps at the shaft head")
	## A heavy haul: raw and appraised stones in every color, and a few sealed Geodes. Each part
	## of the bag has to be heavy enough to wrap on its own.
	for i in range(80):
		var found: Dictionary = DeepForge.roll_stone(rng, mine, 6 + i % 12, 3, {"run": "fit", "source": "vein"}, "fit_haul%d" % i)
		if i % 2 == 0:
			found.appraised = true
			found.inclusions_revealed = true
		me.haul.append(found)
	for i in range(3):
		me.haul.append(DeepEconomy.roll_run_geode(rng, "QUARRY", {"run": "fit"}, "fit_haul_geode%d" % i))
	## The haul went into the run itself; the screen was last shown the shaft head's copy.
	descent.show_state(run)
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
	for part in ["raw", "geodes"]:
		descent._bench._haul_tab = part
		descent._bench._haul_page = 0
		descent._bench._render()
		await _fits(screen, "the bench's %s part of the haul" % part)
	for geode in me.haul.filter(func(s: Dictionary) -> bool: return DeepStone.is_geode(s)).slice(0, 1):
		descent._bench._pick = str(geode.id)
		descent._bench._render()
		await _fits(screen, "the bench with a Geode under the lamp")
	descent._bench._pick = ""
	descent._bench._haul_tab = "gems"
	descent._bench.close()
	descent._run_dock.set_drawer(true)
	await _fits(screen, "the open bag with a heavy haul")
	check(descent._run_dock._drawer.size.y >= 220.0, "the bag drawer grows to show every wrapped row")
	for part in ["raw", "geodes"]:
		descent._run_dock.show_appraised = part == "geodes"
		descent._run_dock.show_raw = part == "raw"
		descent._run_dock.show_geodes = part == "geodes"
		descent._run_dock._key = ""
		descent._run_dock.show_run(run)
		await _fits(screen, "the open bag showing its %s" % part)
	descent._run_dock.show_appraised = true
	descent._run_dock.show_raw = true
	descent._run_dock.show_geodes = false
	for by in ["carat", "grade", "color"]:
		descent._run_dock.sort_by = by
		descent._run_dock._reading = str(me.haul[0].id)
		descent._run_dock._key = ""
		descent._run_dock.show_run(run)
		await _fits(screen, "the open bag sorted by %s, reading a stone" % by)
	descent._run_dock._reading = ""
	descent._run_dock.fits_only = true
	descent._run_dock._key = ""
	descent._run_dock.show_run(run)
	await _fits(screen, "the open bag showing only what fits")
	descent._run_dock.fits_only = false
	descent._run_dock.set_drawer(false)
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
	## The ask in the middle of the screen while one of the party's own things is chosen: on
	## the dock the things that would do stay lit and the rest step back.
	for offered in [["die", me.dice], ["stone", me.haul.slice(0, 6)]]:
		descent._run_dock.offer(str(offered[0]), offered[1], "Which one?")
		descent.show_state(room)
		await _fits(screen, "the ask for one of the party's %s" % str(offered[0]))
		check(descent._ask.is_open(), "the ask is open for a %s" % str(offered[0]))
		descent._run_dock.cancel_offer()
	## A stall's die traded for one of the party's own: the whole bowl, the wrong sizes dimmed.
	var refusals: Dictionary = {str(me.dice[0].id): "Only a d8 can be traded for it."}
	descent._run_dock.offer("die", me.dice, "Trade one of your dice for the Cloud d8 · 140 pyrite", refusals)
	descent.show_state(room)
	await _fits(screen, "the ask for a die to trade, the wrong sizes dimmed")
	var lit: int = 0
	for die in me.dice:
		if descent._run_dock.spotlit("die", str(die.id)):
			lit += 1
	check(lit == me.dice.size() - 1, "every die but the one that will not do stays lit on the dock")
	check(descent._ask.take("die", str(me.dice[1].id)) and not descent._ask.take("die", str(me.dice[0].id)), "a lit die drops into the slot and a refused one does not")
	await _fits(screen, "the ask with a die in its slot")
	descent._run_dock.cancel_offer()
	check(not descent._ask.is_open(), "never mind closes the ask")
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
	## A stone recut or refired on the ladder, and one that broke there.
	for broke in [false, true]:
		var worked: Dictionary = (me.haul[0] as Dictionary).duplicate(true)
		worked.appraised = true
		var worked_result: Dictionary = {"message": "A long message about the wheel, the stone on it and what came off it in the end.", "made": [], "lost": [], "changed": [], "dice": []}
		if broke:
			worked_result.lost = [str(worked.id)]
			worked_result.broke = {"field": "clarity", "stone": worked}
		else:
			worked_result.changed = [worked]
			worked_result.verdict = {"field": "cut", "was": 0, "now": 4, "better": 1}
		descent._hold_page("oddity", {"oddity": "CUTTERS_WHEEL", "room": "oddity", "result": worked_result})
		descent.show_state(run)
		await _fits(screen, "a stone %s at an oddity" % ("broken" if broke else "recut"))
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
		var roll: Dictionary = {"stone": stone, "sides": 6, "roll": 6 if rolls.size() % 3 == 0 else 2, "kept": rolls.size() % 3 == 0, "tier": "FINE"}
		if rolls.size() % 2 == 0:
			## Insured: both throws are named on the card.
			roll.merge({"insured": true, "first": 2, "second": int(roll.roll)})
		rolls.append(roll)
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
	## With a full pocket.
	var pocket: Dictionary = DeepDescent.player(over, app.session.local_id)
	pocket.ore = 99999
	descent._end_shown = true
	descent._over_tab = "haul"
	for page in range(2):
		descent._pages["home"] = page
		descent.show_state(over)
		await _fits(screen, "page %d of the end of a run with a heavy haul" % page)
	## The run's stats, with the biggest numbers the count can show; and the party's, four
	## seats with one gone, every stat led by someone.
	var loud: Dictionary = DeepBattle.fresh_stats()
	for key in ["damage", "overkill", "block", "blocked", "healed", "overheal", "ore", "spent", "taken"]:
		loud[key] = 123456789
	loud.merge({"slain": 999, "slain_wardens": 99, "downs": 3, "revives": 12, "debuffs": {"poison": 99999, "scorched": 5}, "buffs": {"regeneration": 4444},
		"best_hit": {"amount": 98765432, "stone_id": "x", "skill": "STRIKE", "creature": "The Remembered Mirror Regent", "depth": 99}, "best_turn": {"amount": 99999999, "creature": "The Remembered Mirror Regent", "depth": 99, "turn": 12},
		"hands": {"quint": 3, "pair": 40}, "rerolls": 999, "rerolls_given": 1999, "birthstone": 99, "resonance": 999, "turns": 999, "fights": 99, "elites": 9, "wardens": 9, "stones": 99}, true)
	for stone in DeepStone.rail_stones(pocket):
		loud.gems[str(stone.id)] = {"damage": 123456789, "block": 1234567, "healed": 123456, "debuffs": 12345, "ore": 1234, "fires": 999, "best": 98765432}
	pocket.stats = loud
	descent._over_seen = {}
	descent._over_tab = "run"
	## With everything a run can move forward on its "This run" line.
	descent._progress = DescentScreen.progress_parts({"tier": 0, "deepest": {"GLASS_VEINS": 23}},
		{"purses": [{"mine": "GLASS_VEINS", "gold": 650, "warden": 1, "depth": 16}, {"mine": "GLASS_VEINS", "gold": 1300}], "first_met": DeepBestiary.in_mine("GLASS_VEINS")},
		{"mine": "GLASS_VEINS", "deepest": 24, "mines": [{"mine": "GLASS_VEINS", "deepest": 24}]}, app.profile, ["WARRENS"])
	check(descent._progress.size() >= 6, "a run that did everything says it all on its \"This run\" line (%d parts)" % descent._progress.size())
	descent.show_state(over)
	await _fits(screen, "the run's stats at the end of a run")
	descent._progress = []
	var crowd: Dictionary = over.duplicate(true)
	var names: Array = ["", "Marigold Underhill", "Tov", "Quill"]
	var callings: Array = ["", "VESPER", "RUE", "FLORIN"]
	for index in range(1, 4):
		var other: Dictionary = crowd.players[0].duplicate(true)
		other.id = "fit%d" % index
		other.seat = index
		other.name = names[index]
		other.character = callings[index]
		other.stats = loud.duplicate(true)
		other.stats.damage = 1000000 * index
		other.stats.healed = 50000 * (4 - index)
		other.connected = index != 3
		other.left_depth = 4
		crowd.players.append(other)
	descent._over_seen = {}
	descent._over_tab = "party"
	descent.show_state(crowd)
	await _fits(screen, "the party's stats at the end of a run")
	descent._over_tab = "haul"
	descent._over_seen = {}
	## The end of the day's seam, with a heavy haul scored, for every standing, and fallen.
	var dug: Dictionary = over.duplicate(true)
	dug.daily = seam
	dug.records.boss = true
	for standing in standings:
		descent.daily_best = standing
		descent._pages["home"] = 0
		descent.show_state(dug)
		await _fits(screen, "the end of the day's seam, standing %s" % JSON.stringify(standing))
	var fell: Dictionary = dug.duplicate(true)
	fell.outcome = "fallen"
	descent.show_state(fell)
	await _fits(screen, "the end of the day's seam, fallen")
	descent.daily_best = {}
	descent._end_shown = false
	descent._pages = {}
	descent._over_tab = "run"
	descent._over_seen = {}
	## A fight, planning, with every chip on show.
	var guard: int = 0
	while guard < 400 and not (DeepDescent.in_battle(app.session.run) and str(DeepDescent.battle(app.session.run).phase) == "planning"):
		guard += 1
		_advance(app)
	check(DeepDescent.in_battle(app.session.run), "the run reaches a fight")
	if DeepDescent.in_battle(app.session.run):
		var fight: Dictionary = DeepDescent.battle(app.session.run)
		var unit: Dictionary = DeepBattle.player(fight, app.session.local_id)
		unit.statuses = {"poison": 3, "curse": 10}
		unit.block = 6
		unit.buried = [1]
		unit.granted_rerolls = 1
		unit.sparkle = 100
		unit.run_mods = {"shrine": "pair"}
		for foe in fight.enemies:
			foe.statuses = {"poison": 2, "stun": 1}
			foe.block = 4
			foe.stolen_gold = 3
		descent.show_state(app.session.run)
		await _fits(screen, "a fight with every chip on show")

func _void_views(app: Control) -> void:
	## Fourteen Void gems riding five sockets, three or two to a socket: the dock, the bench
	## and the fight must still hold the whole rail on one page, with nothing scrolling.
	var run: Dictionary = app.session.run.duplicate(true)
	run.phase = "chamber"
	run.chamber = {"kind": "merchant", "stock": [], "settled": false, "appraisals": {}}
	var unit: Dictionary = DeepDescent.player(run, app.session.local_id)
	unit.downed = false
	unit.haul.clear()
	var keys: Array = DeepContent.section("skills").keys()
	var count: int = DeepStone.socket_count(unit)
	for index in range(14):
		var stone: Dictionary = DeepStone.make(str(keys[index]), 6, 4, 2, ["VOID"], {}, "fit_void%d" % index)
		stone.appraised = true
		stone.inclusions_revealed = true
		unit.riders[index % count].append(stone)
	DeepStone.normalize_rail(unit)
	check(unit.rail.size() == count and DeepStone.rider_count(unit) == 14, "fourteen riders leave the rail five sockets long")
	var rider: Dictionary = unit.riders[0][0]
	app.descent.show_state(run)
	await _fits(screen, "the run dock with fourteen riders")
	check(app.descent.find_children("*", "ScrollContainer", true, false).is_empty(), "the run dock has nothing that scrolls")
	app.descent._bench.open(run, "gems")
	app.descent._bench._pick = str(rider.id)
	app.descent._bench._render()
	await _fits(screen, "the bench with fourteen riders and one under the lamp")
	check(app.descent._bench.find_children("*", "ScrollContainer", true, false).is_empty(), "the bench has nothing that scrolls")
	app.descent._bench.close()
	var actions: Array = app.descent.appraisal_actions(rider)
	check(not actions.any(func(a: Dictionary) -> bool: return str(a.label).begins_with("Sell")), "the merchant's appraisal offers no sale for a fragile gem")
	var streams: Dictionary = DeepDescent.streams_of(run)
	DeepDescent._start_fight(run, streams, false, "")
	app.descent.show_state(run)
	await _fits(screen, "battle with fourteen riders")
	check(app.descent._battle.find_children("*", "ScrollContainer", true, false).is_empty(), "the battle dock has nothing that scrolls")
	check(app.descent._battle._socket_cards.size() == count + 14, "every gem and rider in the fight has a card or a chip to light")
	DeepDescent._finish(run, "extracted")
	app.descent._end_shown = true
	app.descent.show_state(run)
	await _fits(screen, "the end of a run with fourteen shattered gems")
	var sheet: CanvasLayer = load("res://view/gems/appraisal.gd").new()
	screen.add_child(sheet)
	sheet.call("build", rider, {"shatter": true, "actions": [ {"label": "Keep it"}]})
	sheet.call("finish")
	await _fits(sheet, "a fragile gem shattered under the workshop loupe")
	check(sheet._title.text == "Shattered" and not sheet._view.visible and sheet.actions.size() == 1 and sheet.actions[0].label == "Continue", "skipping a fragile appraisal ends with shards and no keep or sell action")
	sheet.free()

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
			elif str(run.chamber.kind) in DeepDescent.ROCK_ROOMS:
				var unit: Dictionary = app.session.local_player()
				var open_spot: int = -1
				for spot in run.chamber.vein.spots:
					if str(spot.taken).is_empty() and str(spot.get("owner", unit.id)) == str(unit.id):
						open_spot = int(spot.index)
						break
				var can_swing: bool = int(unit.hp) > DeepDescent.swing_cost(run, unit)
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

func _above_dock(descent: Node, what: String) -> void:
	## A page over the room stops short of the dock: nothing laid out on it may run under it.
	await process_frame
	await process_frame
	var found: Array = []
	_scan(descent._page_holder, (descent._area as Control).get_global_rect(), found)
	check(found.is_empty(), "%s stays above the dock: %s" % [what, "; ".join(found.slice(0, 4))])

func _fits(node: Node, what: String) -> void:
	## Twice round the loop, so every container has sorted its children.
	await process_frame
	await process_frame
	var found: Array = []
	_scan(node, Rect2(Vector2.ZERO, CANVAS), found)
	check(found.is_empty(), "%s fits on one page: %s" % [what, "; ".join(found.slice(0, 4))])
	var pointed: Array = []
	_points(node, pointed)
	check(pointed.is_empty(), "%s cuts no capsule's ends to a point: %s" % [what, "; ".join(pointed.slice(0, 4))])
	var small: Array = []
	_small_marks(node, small)
	check(small.is_empty(), "%s sets no die's mark under the text floor: %s" % [what, "; ".join(small.slice(0, 4))])

func _small_marks(node: Node, found: Array) -> void:
	## A die face kept to the text floor (`DiceIcons.readable_face`: a creature's dice, a die
	## plate, the hand on a gem's plate) is measured as a label is: its number is set at the
	## floor or larger, and it stays inside the face's own outline.
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is DiceIcons.Face and (node as DiceIcons.Face).readable and (node as Control).size.y > 0.5:
		var face: DiceIcons.Face = node
		var drawn: int = face.text_size(face.size.y)
		if drawn < DeepUi.min_text() or not face.holds(face.size.y):
			found.append("%s '%s' set at %d on a %d px face (floor %d)" % [face.shape, face.text, drawn, int(face.size.y), DeepUi.min_text()])
	for child in node.get_children():
		_small_marks(child, found)

func _die_plates() -> void:
	## The plate over a die: every face of a d4 to a d20 drawn at one size, each number at the
	## floor inside its outline (a d10's "10" the widest), and the head saying what it rolled.
	var plates: Script = load("res://view/ui/plates.gd")
	var holder := Control.new()
	screen.add_child(holder)
	for shape in ["D4", "D6", "D8", "D10", "D12", "D20"]:
		var die: Dictionary = DeepDice.make(shape, "fit_mark_" + shape)
		var plate: Control = plates.die(die, {"die_id": die.id, "face": 0, "value": DeepDice.face_value(die.faces[0])})
		holder.add_child(plate)
		await _fits(holder, "the plate of a %s" % shape.to_lower())
		var sizes: Dictionary = {}
		for face in plate.find_children("*", "Control", true, false):
			if face is DiceIcons.Face:
				sizes[int(face.size.x)] = true
		check(sizes.size() == 1, "every face on a %s's plate is one size: %s" % [shape.to_lower(), str(sizes.keys())])
		check(plate.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "ROLLED"), "a rolled %s's plate says what it rolled" % shape.to_lower())
		plate.free()
	holder.free()

func _points(node: Node, found: Array) -> void:
	## A faceted box too short for its corners closes each end to a point, and the point cuts
	## across the mark and the digits inside it (`DeepUi.facet_ends`).
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is PanelContainer:
		var face: StyleBox = (node as Control).get_theme_stylebox("panel")
		var height: float = (node as Control).size.y
		if face is StyleBoxFlat and (face as StyleBoxFlat).corner_detail <= DeepUi.FACET_DETAIL and height > 0.5 and not _pointed_on_purpose(face as StyleBoxFlat):
			var flat_face: StyleBoxFlat = face
			var shown: bool = flat_face.bg_color.a > 0.0 or (flat_face.border_color.a > 0.0 and flat_face.border_width_left > 0)
			var end: float = height - flat_face.corner_radius_top_left - flat_face.corner_radius_bottom_left
			if shown and end < height * 0.2:
				found.append("%s (%dpx tall, corner %d)" % [_name(node), int(height), flat_face.corner_radius_top_left])
	for child in node.get_children():
		_points(child, found)

func _pointed_on_purpose(face: StyleBoxFlat) -> bool:
	## A Ledger capsule (`DeepUi.capsule`) comes to a point on purpose, and pads its sides
	## past the point so nothing inside is cut by it.
	return bool(face.get_meta("pointed", false)) and face.content_margin_left >= float(face.corner_radius_top_left) - 1.0

func _scan(node: Node, bounds: Rect2, found: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is ScrollContainer:
		## Only the vault opts into scrolling, so its stones stay readable. The scroller
		## itself must fit the page; its contents can exceed its window.
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

func _bestiary(app: Control) -> void:
	## Every creature picked on its mine's page, on every page of its sheet, and one not met.
	var home: Control = app.home
	for mine in DeepContent.mines_in_order():
		for key in DeepBestiary.in_mine(str(mine)):
			home._bestiary_pick = str(key)
			home._bestiary_leaf = 0
			home.open("bestiary", true)
			await process_frame
			var leaves: Node = home.find_child("BestiaryLeaves", true, false)
			var count: int = leaves.get_child_count() if leaves != null else 1
			for leaf in range(count):
				home._bestiary_leaf = leaf
				home.open("bestiary", true)
				await _fits(screen, "the bestiary on %s, page %d" % [str(key), leaf])
	var kept: Dictionary = app.profile.bestiary.get("THE_HOLLOW_CROWN", {})
	app.profile.bestiary.erase("THE_HOLLOW_CROWN")
	home._bestiary_pick = "THE_HOLLOW_CROWN"
	home.open("bestiary", true)
	await _fits(screen, "the bestiary on a creature not met")
	app.profile.bestiary.THE_HOLLOW_CROWN = kept

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
			profile.bowl.append(DeepDice.make(str(key), "fit_bowl_%s_%d" % [key, copy]))
	profile.gold = 123456
	for i in range(40):
		profile.history.append({"date": "2026-08-%02d" % (1 + i % 28), "mine": DeepContent.starter_mine(), "depth": 4 + i % 20, "outcome": ["extracted", "fallen", "conquered"][i % 3], "stones": i % 9})
	profile.records.runs = 40
	## Daily digs among them, with the longest names and the biggest numbers the Ledger shows.
	for i in range(6):
		profile.history.append({"date": "2026-09-%02d" % (1 + i), "mine": "GLASS_VEINS", "deepest_mine": "GLASS_VEINS", "depth": 99, "outcome": "extracted", "stones": 0, "daily": true, "score": 9999999, "gold": 999999})
	profile.records.best_daily = 9999999
	## Every creature met, in every mine, half of them still new.
	var everywhere: Dictionary = {}
	for key in DeepContent.mines_in_order():
		everywhere[str(key)] = 99
	var index: int = 0
	for key in DeepContent.section("creatures"):
		profile.bestiary[str(key)] = {"met": 99999, "slain": 99999, "lost": 9999, "mines": everywhere.duplicate(), "first": "2026-10-15", "fresh": index % 2 == 0}
		index += 1
	profile.records.daily_bests = []
	for i in range(30):
		profile.records.daily_bests.append({"date": "2026-09-%02d" % (1 + i), "score": 9999999, "gold": 999999})

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
