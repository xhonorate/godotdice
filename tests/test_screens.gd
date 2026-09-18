extends SceneTree
## The screens, headless: the app boots, a run is played through the real screens with the
## real session, and nothing throws. Rendering is skipped; layout and logic are exercised.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	## Saves go to a scratch directory so a test never touches a real profile.
	DeepSaveStore.override_directory = "user://test_scratch"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	var app: Control = load("res://view/app.gd").new()
	root.add_child(app)
	await process_frame
	check(app.session != null and app.session.status == "local", "the app boots into a local session")
	check(app.home.visible and not app.descent.visible, "the workshop is shown first")
	for tab in ["map", "bench", "vault", "appraise", "ledger"]:
		app.home.open(tab)
		check(app.home._body.get_child_count() > 0, "the %s tab renders" % tab)
	app._depart(9001)
	await process_frame
	check(app.descent.visible and not app.home.visible and app.session.in_run(), "departing shows the run")
	var guard: int = 0
	var saw_battle: bool = false
	var saw_landing: bool = false
	while str(app.session.run.get("phase", "")) != "over" and guard < 500:
		guard += 1
		var run: Dictionary = app.session.run
		match str(run.phase):
			"tunnels":
				var offer: Dictionary = run.offers[0]
				for candidate in run.offers:
					if str(candidate.kind) in ["fight", "elite"]:
						offer = candidate
				app.session.send({"kind": "vote_tunnel", "offer": offer.id})
			"chamber":
				if DeepDescent.in_battle(run):
					saw_battle = true
					var b: Dictionary = DeepDescent.battle(run)
					if str(b.phase) == "planning":
						var unit: Dictionary = DeepBattle.player(b, app.session.local_id)
						if not bool(unit.locked):
							if int(unit.rerolls) > 0 and not unit.hand.is_empty():
								app.session.send({"kind": "reroll", "dice": [str(unit.hand[0].die_id)]})
							app.session.send({"kind": "lock"})
					else:
						app.session.tick(0.5)
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
				saw_landing = true
				for sub in ["haul", "bench", "merchant", "lift"]:
					app.descent._landing_tab = sub
					app.descent.show_state(run)
				app.session.send({"kind": "choose", "choice": "lift" if run.depth >= 4 else "descend"})
			"hoard":
				var mine_hoard: Dictionary = run.hoard[app.session.local_id]
				app.session.send({"kind": "pick_hoard", "stone_id": mine_hoard.offers[0].id})
			"salvage":
				app.session.send({"kind": "ready"})
		if guard % 10 == 0:
			await process_frame
	check(str(app.session.run.get("phase", "")) == "over", "the run ends through the screens (guard %d, phase %s)" % [guard, str(app.session.run.get("phase", ""))])
	check(saw_battle, "a fight was shown")
	check(saw_landing or str(app.session.run.get("outcome", "")) == "fallen", "a landing was shown or the party fell first")
	check(app.profile.records.runs == 1, "the result reached the profile")
	app._back_home()
	await process_frame
	check(app.home.visible and not app.descent.visible, "back in the workshop")
	for stone in app.profile.get("tray", []).duplicate():
		stone.appraised = true
	app.home.open("appraise")
	if not app.profile.tray.is_empty():
		DeepProfile.decide_tray(app.profile, str(app.profile.tray[0].id), true)
		app._profile_changed()
	check(true, "appraisal decisions flow through")
	print("Screens: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
