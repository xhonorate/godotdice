extends SceneTree
## Boots the game, drives it to a screen, and saves what it looks like.
##   godot --path . --script tools/screenshot.gd -- <target> out.png [seed]
## Targets: home (map) | map_party | bench | roster_sockets | vault | appraise | ledger |
##          grubstake | grubstake_pick | grubstake_result |
##          tunnels | vein | vein_done | oddity | smithy | carver | well |
##          landing | merchant | lift | run_bench | run_bench_dice | battle | battle_fx | battle_status | spoils |
##          over | inspect_stone | inspect_die | inspect_opal | vault_opals | inspect_flaw | vault_flaws | inspect_creature | menu | menu_settings |
##          abandon | map_lit |
##          crossroads | crossroads_hover | walk | walk_in | rockfall | crumble | vein_hover | vein_strike |
##          lift_ride | hoard | appraisal | appraisal_run
## `appraisal` puts a raw stone from the tray under the loupe at home (weighed against a kept
## one of its skill) and `appraisal_run` buys an appraisal at a merchant; the 4th argument is
## how far into the ceremony to shoot, in seconds.
## Needs a window: this is the one tool here that is not headless.

const HOME_TABS: Dictionary = {"home": "map", "map": "map", "map_party": "map", "bench": "roster", "roster": "roster", "roster_sockets": "roster",
	"vault": "vault", "appraise": "appraise", "ledger": "ledger", "appraisal": "appraise"}

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var target: String = str(args[0]) if args.size() > 0 else "home"
	var out: String = str(args[1]) if args.size() > 1 else "build/shot.png"
	var seed_value: int = int(args[2]) if args.size() > 2 else 9001
	## For the moments of the mine (walk, walk_in, rockfall, crumble): how long after the
	## moment begins to take the picture, overriding each target's own.
	var moment: float = float(args[3]) if args.size() > 3 else -1.0
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
	if HOME_TABS.has(target) or target in ["inspect_stone", "inspect_die", "inspect_opal", "vault_opals", "inspect_flaw", "vault_flaws"]:
		_enrich(app.profile, seed_value)
		app._profile_changed()
		## The views inside a tab: the map's party column, a lapidary's sockets.
		match target:
			"map_party": app.home._side = "party"
			"roster_sockets": app.home._roster_view = "sockets"
		app.home.open(str(HOME_TABS.get(target, "vault")))
		var inspector: Script = load("res://view/inspect/inspector.gd")
		if target == "appraisal":
			## A raw stone with two things frozen inside it, and a plainer one of its skill kept.
			var pick: Dictionary = app.profile.tray[1]
			pick.clarity = 1
			pick.inclusions = DeepContent.section("inclusions").keys().slice(3, 5)
			var kept: Dictionary = pick.duplicate(true)
			kept.id = "shot_kept"
			kept.carat = maxi(1, int(pick.carat) - 3)
			kept.cut = mini(4, int(pick.cut) + 1)
			kept.clarity = 3
			kept.inclusions = []
			DeepProfile.keep(app.profile, kept)
			app.home._appraise_pick = str(pick.id)
			app.home.open("appraise")
			await create_timer(0.6).timeout
			app.home._appraise_stone(pick)
			await create_timer(moment if moment >= 0.0 else 3.0).timeout
			_save(out)
			return
		if target in ["inspect_flaw", "vault_flaws"]:
			## One stone per class of inclusion, all cut alike, so the only thing telling
			## them apart is what is frozen inside. This is the shot that says whether a
			## Star reads as a star and a Fracture as a crack, rather than both as a
			## darkened facet, which is all either of them used to be.
			## The vault keeps one card per skill, so each class needs a skill of its own.
			var carriers: Array = ["GLIMMER", "REFRACT", "POLISH", "MIRROR", "CASCADE", "FACET", "ECHO", "PRISM"]
			var seen: Dictionary = {}
			var lamp: Dictionary = {}
			for key in DeepContent.section("inclusions").keys():
				var cls: String = str(DeepContent.inclusion(str(key)).get("class", ""))
				if cls.is_empty() or seen.has(cls) or seen.size() >= carriers.size():
					continue
				## Two of the same, because one lands where the seed puts it and the shot
				## should not turn on whether that was behind the emblem.
				var one: Dictionary = DeepStone.make(str(carriers[seen.size()]), 16, 4, 1, [str(key), str(key)], {"run": "shot", "source": "vein", "mine": DeepContent.starter_mine(), "depth": 6}, "flaw_" + cls)
				seen[cls] = true
				one.appraised = true
				one.inclusions_revealed = true
				DeepProfile.keep(app.profile, one)
				# The vault is keyed by skill, so the lamp takes the skill, not the stone id.
				if cls == "FRACTURE" or lamp.is_empty():
					lamp = app.profile.vault[str(one.skill)]
			app._profile_changed()
			app.home._vault_filter = "WHITE"
			app.home.open("vault")
			await create_timer(0.6).timeout
			if target == "inspect_flaw":
				inspector.call("stone", lamp)
		elif target in ["inspect_opal", "vault_opals"]:
			## One of every opal kept, and one of them under the lamp. They are the only
			## stones in the game cut as cabochons, so this is the shot that says whether
			## the dome reads as a dome and the play-of-color as an opal's and not a
			## brilliant's fire.
			var lamp: Dictionary = {}
			for key in DeepForge.opal_pool():
				var one: Dictionary = DeepStone.make(str(key), 14, 4, 4, [], {"run": "shot", "source": "hoard", "mine": DeepContent.starter_mine(), "depth": 8}, "opal_" + str(key))
				one.appraised = true
				one.inclusions_revealed = true
				DeepProfile.keep(app.profile, one)
				if lamp.is_empty() or str(key) == "FIRE_OPAL":
					lamp = one
			app._profile_changed()
			app.home._vault_filter = "OPAL"
			app.home.open("vault")
			await create_timer(0.6).timeout
			if target == "inspect_opal":
				inspector.call("stone", lamp)
		elif target == "inspect_stone":
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
	var want: Dictionary = {"crossroads": "fight", "crossroads_hover": "fight", "walk": "fight", "walk_in": "fight", "rockfall": "fight", "crumble": "fight", "menu": "vein", "menu_settings": "vein", "abandon": "vein", "map_lit": "vein", "tunnels": "vein", "vein": "vein", "vein_done": "vein", "vein_hover": "vein", "vein_strike": "vein", "oddity": "oddity", "battle": "fight", "battle_fx": "fight",
		"battle_status": "fight", "spoils": "fight", "inspect_creature": "fight", "hoard": "fight"}
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
				unit.statuses = {"poison": 3, "curse": 10}
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
		if target in ["crossroads", "crossroads_hover", "walk", "walk_in", "rockfall"] and phase == "tunnels" and int(run.depth) >= 1 and not app.descent.walking():
			## The mine itself: the mouths lit at the crossroads, the walk down a tunnel, the
			## way on sealed as a fight begins.
			var fights: Array = run.offers.filter(func(o: Dictionary) -> bool: return str(o.kind) in ["fight", "elite"] and not bool(o.get("hidden", false)))
			if target != "rockfall" or not fights.is_empty():
				app.descent._hold = {}
				app.descent.show_state(run)
				await create_timer(3.4).timeout
				if target in ["crossroads", "crossroads_hover"]:
					if target == "crossroads_hover":
						app.descent._stage._set_hover(0)
						await create_timer(0.8).timeout
					_save(out)
					return
				var offer: Dictionary = fights[0] if not fights.is_empty() else run.offers[0]
				app.session.send({"kind": "vote_tunnel", "offer": offer.id})
				match target:
					"walk":
						await create_timer(moment if moment >= 0.0 else 1.45).timeout
					"walk_in":
						await create_timer(moment if moment >= 0.0 else 2.7).timeout
					"rockfall":
						while app.descent.walking():
							await process_frame
						await create_timer(moment if moment >= 0.0 else 0.8).timeout
				_save(out)
				return
		if target == "crumble" and str(app.descent._hold.get("kind", "")) == "victory":
			if str(app.descent._hold.get("stage", "")) == "spoils":
				## Wait for the spoils to land and the way on to start opening.
				while not app.descent._hold.is_empty():
					await process_frame
				await create_timer(moment if moment >= 0.0 else 0.45).timeout
				_save(out)
				return
			await process_frame
			continue
		if target == "spoils" and str(app.descent._hold.get("kind", "")) == "victory":
			if str(app.descent._hold.get("stage", "")) == "spoils":
				await create_timer(moment if moment >= 0.0 else 1.0).timeout
				_save(out)
				return
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
		if target == "grubstake_result":
			if not app.descent._hold.is_empty():
				break
			if phase == "grubstake":
				## Terms left to chance: they land on a stone drawn from the rail.
				var terms: Dictionary = DeepBoons._make_offer(run, app.session.local_player(), "terms", ["COST_CHIPPED", "REWARD_CARATS"], DeepRng.streams(seed_value).boons)
				terms.id = "stake_shot"
				run.grubstake.offers[app.session.local_id].append(terms)
				app.session.send({"kind": "stake", "offer": "stake_shot", "payload": {}})
				await process_frame
				continue
		if target == "grubstake_pick" and phase == "grubstake":
			## A pick stake taken, its three on show.
			var picking: Dictionary = DeepBoons._make_offer(run, app.session.local_player(), "stone", ["PICK_STONE"], DeepRng.streams(seed_value).boons)
			picking.id = "stake_shot"
			run.grubstake.offers[app.session.local_id].append(picking)
			app.descent._stake_choosing = "stake_shot"
			app.descent.show_state(run)
			break
		if phase == "grubstake":
			var staker: Dictionary = app.session.local_player()
			if str(staker.get("stake", "")).is_empty():
				var offers: Array = run.grubstake.offers.get(app.session.local_id, [])
				var offer: Dictionary = offers[0]
				var payload: Dictionary = {}
				if offer.needs.has("pick"):
					payload.pick = 0
				app.session.send({"kind": "stake", "offer": offer.id, "payload": payload})
			continue
		if target == "tunnels" and phase == "tunnels" and int(run.depth) >= 4:
			## Past the first landing, so the lantern's fog shows on the last row.
			app.descent._hold = {}
			app.descent.show_state(run)
			break
		if target == "vein" and phase == "chamber" and str(run.chamber.get("kind", "")) in ["vein", "vug"] and int(app.session.local_player().get("strikes", 0)) >= 2:
			break
		if target in ["vein_hover", "vein_strike"] and phase == "chamber" and str(run.chamber.get("kind", "")) in ["vein", "vug"] and not app.descent.walking() and int(app.session.local_player().get("strikes", 0)) == 0:
			## The outcrop before anyone has struck it: pointed at, or with a pick going in.
			app.descent.show_state(run)
			await create_timer(1.4).timeout
			var spot_index: int = 0
			for spot in run.chamber.vein.spots:
				if str(spot.glint) == "bright":
					spot_index = int(spot.index)
			if target == "vein_hover":
				app.descent._stage._hover_pick("spot:%d" % spot_index)
				await create_timer(moment if moment >= 0.0 else 0.6).timeout
			else:
				app.descent._press_pick("spot:%d" % spot_index)
				await create_timer(moment if moment >= 0.0 else 0.3).timeout
			_save(out)
			return
		if target in ["oddity"] + DeepDescent.CARD_ROOMS and phase == "chamber" and str(run.chamber.get("kind", "")) == target:
			break
		if target == "landing" and phase == "landing":
			break
		if target == "lift" and phase == "landing" and not str(app.session.local_player().get("respite", "")).is_empty():
			break
		if target == "merchant" and phase == "chamber" and str(run.chamber.get("kind", "")) == "merchant":
			break
		if target == "appraisal_run" and phase == "chamber" and str(run.chamber.get("kind", "")) == "merchant":
			while app.descent.walking():
				await process_frame
			await create_timer(1.0).timeout
			var raws: Array = app.session.local_player().haul.filter(func(st: Dictionary) -> bool: return not bool(st.get("appraised", false)))
			app.session.send({"kind": "appraise", "stone_id": str(raws[0].id)})
			await create_timer(moment if moment >= 0.0 else 3.0).timeout
			_save(out)
			return
		if target in ["run_bench", "run_bench_dice"] and phase == "tunnels" and int(run.depth) >= 2:
			## Something to sort: a few raw and appraised stones in the haul.
			var me: Dictionary = app.session.local_player()
			var mine: Dictionary = DeepContent.mine(DeepContent.starter_mine())
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			for i in range(5):
				var found: Dictionary = DeepForge.roll_stone(rng, mine, 6 + i, 3, {"run": "shot", "source": "vein"}, "shot_haul%d" % i)
				if i % 2 == 0:
					found.appraised = true
					found.inclusions_revealed = true
				me.haul.append(found)
			app.descent._hold = {}
			app.descent.show_state(run)
			app.descent.open_bench("dice" if target == "run_bench_dice" else "gems")
			break
		if target in ["over", "lift_ride"] and phase == "over":
			break
		if target == "hoard" and phase == "hoard":
			if app.descent._hold.is_empty():
				break
			## The spoils are still flying: wait for them without spending the guard.
			guard -= 1
			await process_frame
			continue
		match phase:
			"tunnels":
				var offer: Dictionary = run.offers[0]
				for candidate in run.offers:
					if str(candidate.kind) == str(want.get(target, "fight")) and not bool(candidate.get("hidden", false)):
						offer = candidate
				if target in ["vein", "vein_done", "vein_hover", "vein_strike"] and str(offer.kind) != "landing":
					## The shot wants an outcrop: make the next way one, whatever the chart rolled.
					offer.kind = "vein"
				if target in DeepDescent.CARD_ROOMS and str(offer.kind) != "landing":
					## The shot wants a smithy or a carver: the next tunnel is one.
					offer.kind = target
				if target in ["merchant", "appraisal_run"] and int(run.depth) >= 1 and str(offer.kind) != "landing":
					## The shot wants a stall: the next tunnel is one, and there is ore to spend and
					## raw stones to look at.
					offer.kind = "merchant"
					var me: Dictionary = app.session.local_player()
					me.ore = int(me.get("ore", 0)) + 60
					for i in range(2):
						me.haul.append(DeepForge.roll_stone(DeepRng.streams(seed_value + i).stones, DeepContent.mine(DeepContent.starter_mine()), 5, 2, {}, "shot_raw%d" % i))
				app.session.send({"kind": "vote_tunnel", "offer": offer.id})
			"chamber":
				if DeepDescent.in_battle(run):
					var b: Dictionary = DeepDescent.battle(run)
					if target == "hoard":
						## The shot wants the Warden dead: every creature comes in at a scratch.
						for foe in b.enemies:
							foe.hp = mini(int(foe.hp), 1)
					if str(b.phase) == "planning":
						app.session.send({"kind": "lock"})
					else:
						app.session.tick(1.0)
				elif str(run.chamber.kind) in ["vein", "vug"]:
					var unit: Dictionary = app.session.local_player()
					if bool(unit.get("mining", false)) and not target in ["vein_hover", "vein_strike"]:
						var open_spot: int = -1
						for spot in run.chamber.vein.spots:
							if str(spot.taken).is_empty():
								open_spot = int(spot.index)
								break
						var can_swing: bool = int(unit.hp) > DeepDescent.strike_cost(int(unit.get("strikes", 0)), bool(run.chamber.vein.get("hazard", false)))
						if open_spot >= 0 and can_swing:
							app.session.send({"kind": "strike", "spot": open_spot})
						else:
							app.session.send({"kind": "stop_mining"})
				elif str(run.chamber.kind) in ["oddity"] + DeepDescent.CARD_ROOMS:
					var oddity: Dictionary = DeepContent.oddity(str(run.chamber.oddity))
					app.session.send({"kind": "oddity", "choice": oddity.choices[oddity.choices.size() - 1].id})
				elif str(run.chamber.kind) == "merchant":
					app.session.send({"kind": "leave"})
			"landing":
				if target in ["over", "lift_ride"]:
					app.session.send({"kind": "choose", "choice": "lift"})
				elif str(app.session.local_player().get("respite", "")).is_empty():
					app.session.send({"kind": "respite", "choice": "rest"})
				else:
					app.session.send({"kind": "choose", "choice": "descend"})
			"hoard":
				if target != "hoard":
					var mine_hoard: Dictionary = run.hoard[app.session.local_id]
					app.session.send({"kind": "pick_hoard", "stone_id": mine_hoard.offers[0].id})
			"salvage":
				app.session.send({"kind": "ready"})
			"over":
				break
		if guard % 4 == 0:
			await process_frame
	## Wait by the clock, not by frames: a fast screen would otherwise catch the fades mid-way.
	## A walk in progress finishes first, so the shot is of the room, not the tunnel.
	while app.descent.walking():
		await process_frame
	## The end of a run is shot once the lift has gone up (or the lights out) and the summary is up.
	while target == "over" and not app.descent._end_shown:
		await process_frame
	if target == "lift_ride":
		await create_timer(moment if moment >= 0.0 else 3.5).timeout
		_save(out)
		return
	if target != "battle_fx":
		await create_timer(2.2 if target != "tunnels" else 3.4).timeout
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
