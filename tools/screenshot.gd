extends SceneTree
## Boots the game, drives it to a screen, and saves what it looks like.
##   godot --path . --script tools/screenshot.gd -- home|battle|landing out.png [seed]
## Needs a window: this is the one tool here that is not headless.

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
	failsafe.wait_time = 45.0
	failsafe.one_shot = true
	failsafe.timeout.connect(func() -> void:
		print("screenshot timed out")
		quit(1))
	root.add_child(failsafe)
	failsafe.start()
	root.size = Vector2i(1600, 900)
	var app: Control = load("res://view/app.gd").new()
	root.add_child(app)
	await process_frame
	await process_frame
	if target != "home":
		app._depart(seed_value)
		var guard: int = 0
		while guard < 400:
			guard += 1
			var run: Dictionary = app.session.run
			var phase: String = str(run.get("phase", ""))
			if target == "battle" and DeepDescent.in_battle(run) and str(DeepDescent.battle(run).phase) == "planning":
				break
			if target == "landing" and phase == "landing":
				break
			if target == "tunnels" and phase == "tunnels" and int(run.depth) >= 2:
				break
			match phase:
				"tunnels":
					var offer: Dictionary = run.offers[0]
					for candidate in run.offers:
						if str(candidate.kind) == ("fight" if target == "battle" else "vein"):
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
				"over", "salvage", "hoard":
					break
	for _i in range(70):
		await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out.get_base_dir()))
	image.save_png(out)
	print("saved ", out, " ", image.get_size())
	quit()
