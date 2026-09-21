extends SceneTree
## Boots the game, drives it to a screen, and saves what it looks like.
##   godot --path . --script tools/screenshot.gd -- <target> out.png [seed]
## Targets: home (map) | bench | vault | appraise | ledger | grubstake | tunnels | vein | vein_done | oddity |
##          landing | merchant | lift | landing_bench | battle | battle_fx | battle_status | spoils |
##          over | inspect_stone | inspect_die | inspect_creature | menu | menu_settings |
##          abandon | map_lit
## Needs a window: this is the one tool here that is not headless.

const HOME_TABS: Dictionary = {"home": "map", "map": "map", "bench": "roster", "roster": "roster", "vault": "vault", "appraise": "appraise", "ledger": "ledger"}

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var target: String = str(args[0]) if args.size() > 0 else "home"
	var out: String = str(args[1]) if args.size() > 1 else "build/shot.png"
	var seed_value: int = int(args[2]) if args.size() > 2 else 9001
	DeepSaveStore.override_directory = "user://shot_scratch"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	## Whatever happens, the window closes.
	var failsafe := Timer.new()
	failsafe.wait_time = 60.0
	failsafe.one_shot = true
	failsafe.autostart = true
	failsafe.timeout.connect(func() -> void:
		print("screenshot timed out")
		quit(1))
	root.add_child(failsafe)
	root.size = Vector2i(1600, 900)
	var app: Control = load("res://view/app.gd").new()
	root.add_child(app)
	await process_frame
	await process_frame
	if HOME_TABS.has(target) or target in ["inspect_stone", "inspect_die"]:
		_enrich(app.profile, seed_value)
		app._profile_changed()
		app.home.open(str(HOME_TABS.get(target, "vault")))
		var inspector: Script = load("res://view/inspect/inspector.gd")
		if target == "inspect_stone":
			var keys: Array = app.profile.vault.keys()
			keys.sort()
			var best: Dictionary = app.profile.records.best.get("stone", app.profile.vault[keys[0]])
			inspector.call("stone", best)
		elif target == "inspect_die":
			inspector.call("die", app.profile.bowl[app.profile.bowl.size() - 1])
		await create_timer(1.6).timeout
		_save(out)
		return
	app._depart(seed_value)
	var want: Dictionary = {"menu": "vein", "menu_settings": "vein", "abandon": "vein", "map_lit": "vein", "tunnels": "vein", "vein": "vein", "vein_done": "vein", "oddity": "oddity", "battle": "fight", "battle_fx": "fight",
		"battle_status": "fight", "spoils": "fight", "inspect_creature": "fight"}
	var landing_tab: Dictionary = {"landing": "haul", "merchant": "merchant", "lift": "lift", "landing_bench": "bench"}
	var guard: int = 0
	var locked_at: int = -1
	while guard < 600:
		guard += 1
		var run: Dictionary = app.session.run
		var phase: String = str(run.get("phase", ""))
		if target in ["battle_status", "inspect_creature"] and DeepDescent.in_battle(run) and str(DeepDescent.battle(run).phase) == "planning":
			var b: Dictionary = DeepDescent.battle(run)
			if target == "battle_status":
				## Everything at once, so every chip can be seen.
				var unit: Dictionary = DeepBattle.player(b, app.session.local_id)
				unit.statuses = {"poison": 3, "curse": 25}
				unit.block = 6
				unit.buried = [1]
				unit.granted_rerolls = 1
				unit.sparkle = 3
				unit.run_mods = {"shrine": "pair"}
				b.turn = 5
				b.enemies[0].statuses = {"poison": 2, "stun": 1}
				b.enemies[0].block = 4
				b.enemies[0].stolen_gold = 3
				app.descent.show_state(run)
			else:
				for _i in range(40):
					await process_frame
				load("res://view/inspect/inspector.gd").call("creature", b.enemies[0], b, {})
			break
		if target == "spoils" and not app.descent._hold.is_empty():
			if str(app.descent._hold.get("stage", "")) == "spoils":
				break
			await process_frame
			continue
		if target == "vein_done" and not app.descent._hold.is_empty() and str(app.descent._hold.kind) == "vein":
			break
		if target in ["battle", "battle_fx"] and DeepDescent.in_battle(run):
			var b: Dictionary = DeepDescent.battle(run)
			if target == "battle" and str(b.phase) == "planning":
				break
			if target == "battle_fx":
				if str(b.phase) == "planning" and locked_at < 0:
					app.session.send({"kind": "lock"})
					locked_at = guard
				elif locked_at >= 0 and str(b.phase) == "resolving":
					## Let the resolution play on its own clock and catch it mid-blow.
					for _i in range(52):
						await process_frame
					break
		if target in ["menu", "menu_settings", "abandon", "map_lit"] and phase == "tunnels" and int(run.depth) >= 1:
			app.descent._hold = {}
			app.descent.show_state(run)
			match target:
				"menu", "menu_settings":
					app.open_menu()
					if target == "menu_settings":
						app.menu._show("settings")
				"abandon":
					app.session.local_player().haul.append(DeepForge.roll_stone(DeepRng.streams(3).stones, DeepContent.mine(DeepContent.starter_mine()), 3, 0, {}, "shot_raw"))
					app.open_menu()
					app.menu._show("abandon")
					await create_timer(0.6).timeout
					app.menu.abandon_requested.emit()
					app.menu.close()
				"map_lit":
					app.session.send({"kind": "light"})
			break
		if target == "grubstake" and phase == "grubstake":
			break
		if phase == "grubstake":
			var staker: Dictionary = app.session.local_player()
			if str(staker.get("stake", "")).is_empty():
				var offers: Array = run.grubstake.offers.get(app.session.local_id, [])
				var offer: Dictionary = offers[0]
				var payload: Dictionary = {}
				if offer.needs.has("socket"):
					payload.socket = 0
				if offer.needs.has("pick"):
					payload.pick = 0
				app.session.send({"kind": "stake", "offer": offer.id, "payload": payload})
			continue
		if target == "tunnels" and phase == "tunnels" and int(run.depth) >= 4:
			## Past the first landing, so the lantern's fog shows on the last row.
			app.descent._hold = {}
			app.descent.show_state(run)
			break
		if target == "vein" and phase == "chamber" and str(run.chamber.get("kind", "")) in ["vein", "vug"] and int(app.session.local_player().get("strikes", 0)) == 1:
			break
		if target == "oddity" and phase == "chamber" and str(run.chamber.get("kind", "")) == "oddity":
			break
		if landing_tab.has(target) and phase == "landing":
			app.descent._landing_tab = str(landing_tab[target])
			app.descent.show_state(run)
			break
		if target == "over" and phase == "over":
			break
		match phase:
			"tunnels":
				var offer: Dictionary = run.offers[0]
				for candidate in run.offers:
					if str(candidate.kind) == str(want.get(target, "fight")) and not bool(candidate.get("hidden", false)):
						offer = candidate
				app.session.send({"kind": "vote_tunnel", "offer": offer.id})
			"chamber":
				if DeepDescent.in_battle(run):
					var b: Dictionary = DeepDescent.battle(run)
					if str(b.phase) == "planning":
						app.session.send({"kind": "lock"})
					else:
						app.session.tick(1.0)
				elif str(run.chamber.kind) in ["vein", "vug"]:
					var unit: Dictionary = app.session.local_player()
					if int(unit.strikes) > 0:
						for spot in run.chamber.vein.spots:
							if str(spot.taken).is_empty():
								app.session.send({"kind": "strike", "spot": spot.index})
								break
				elif str(run.chamber.kind) == "oddity":
					var oddity: Dictionary = DeepContent.oddity(str(run.chamber.oddity))
					app.session.send({"kind": "oddity", "choice": oddity.choices[oddity.choices.size() - 1].id})
			"landing":
				app.session.send({"kind": "choose", "choice": "lift" if target == "over" else "descend"})
			"hoard":
				var mine_hoard: Dictionary = run.hoard[app.session.local_id]
				app.session.send({"kind": "pick_hoard", "stone_id": mine_hoard.offers[0].id})
			"salvage":
				app.session.send({"kind": "ready"})
			"over":
				break
		if guard % 4 == 0:
			await process_frame
	## Wait by the clock, not by frames: a fast screen would otherwise catch the fades mid-way.
	if target != "battle_fx":
		await create_timer(2.2).timeout
	_save(out)

func _enrich(profile: Dictionary, seed_value: int) -> void:
	## A workshop with something in it: a handful of kept stones and a tray to appraise.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mine: Dictionary = DeepContent.mine(DeepContent.starter_mine())
	for i in range(14):
		var stone: Dictionary = DeepForge.roll_stone(rng, mine, 4 + i, 4, {"run": "shot", "source": "vein", "mine": DeepContent.starter_mine(), "depth": 4 + i}, "shot%d" % i)
		DeepProfile.keep(profile, stone)
	for i in range(3):
		var raw: Dictionary = DeepForge.roll_stone(rng, mine, 10 + i * 4, 6, {"run": "shot", "source": "vein"}, "tray%d" % i)
		profile.tray.append(raw)
	profile.tray[0].appraised = true
	profile.tray[0].inclusions_revealed = true
	profile.gold = 1240
	profile.records.runs = 6
	profile.records.extractions = 4
	profile.records.falls = 2
	profile.mines[DeepContent.starter_mine()].deepest = 13
	profile.mines[DeepContent.starter_mine()].runs = 6
	profile.mines[DeepContent.starter_mine()].wardens = [8]
	for i in range(5):
		profile.history.append({"date": "2026-09-1%d" % i, "mine": DeepContent.starter_mine(), "depth": 4 + i * 2, "outcome": "fallen" if i % 3 == 2 else "extracted", "stones": i + 1})

func _save(out: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out.get_base_dir()))
	image.save_png(out)
	print("saved ", out, " ", image.get_size())
	quit()
