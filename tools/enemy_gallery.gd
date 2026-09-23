extends SceneTree
## Reproducible enemy UI moments, with real simulation events and die geometry.
## Godot --path . --script tools/enemy_gallery.gd -- planning|roll|reveal|power|impact|suspense|combo|miss out.png [width height]
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var moment: String = str(args[0]) if args.size() > 0 else "planning"
	var path: String = str(args[1]) if args.size() > 1 else "build/enemy.png"
	root.size = Vector2i(int(args[2]), int(args[3])) if args.size() > 3 else Vector2i(1600, 900)
	var player_dice: Array = []
	for i in range(5):
		player_dice.append(DeepDice.make("D6", DeepContent.die("D6"), "p%d" % i))
	var player: Dictionary = DeepBattle.make_player("p", "Lapidary", "ARDOR", [], player_dice)
	player.birthstone = {}
	var rng: Dictionary = DeepRng.streams(1234, ["dice", "creatures"])
	var combo: bool = moment in ["suspense", "combo", "miss"]
	var state: Dictionary = DeepBattle.begin([player], ["MAGPIE" if combo else "CAVE_TICK", "QUARTZ_GOLEM"], {"depth": 1}, rng.dice, rng.creatures)
	var foe: Dictionary = state.enemies[0]
	# Fixed faces make the fixture deterministic while keeping the 3D die's actual shape.
	var numbers: Array = [3, 3, 2 if moment == "miss" else 3] if combo else [6]
	for i in range(foe.dice.size()):
		for face in foe.dice[i].faces:
			face.value = int(numbers[i])
	if moment in ["suspense", "combo", "miss"]:
		# Keep the last die fair for the real possibility check; find a matching RNG state
		# at its roll below rather than making suspense depend on a predetermined face set.
		foe.dice[2] = DeepDice.make("D4", DeepContent.die("D4"), str(foe.dice[2].id))
	load("res://view/run/mine_stage.gd").quality_pref = 2
	var screen: Control = load("res://view/battle/battle_screen.gd").new()
	root.add_child(screen)
	screen.local_id = "p"
	screen.show_state(state.duplicate(true), 1, DeepBattle.forecast(state, "p"))
	await create_timer(2.2).timeout
	screen._pin_enemy("e0")
	if moment != "planning":
		DeepBattle.start_resolution(state)
		while DeepBattle.has_steps(state):
			if combo and int(foe.get("next_die", 0)) == 2 and not state.queue.is_empty() and str(state.queue[0].kind) == "enemy_roll":
				for seed_value in range(100):
					var probe := RandomNumberGenerator.new()
					probe.seed = seed_value
					if int(DeepDice.roll_one(foe.dice[2], probe).value) == int(numbers[2]):
						rng.creatures.seed = seed_value
						break
			var event: Dictionary = DeepBattle.step(state, rng.dice, rng.creatures)
			screen.show_state(state.duplicate(true), 1, {})
			screen.perform(event)
			var caught: bool = str(event.get("unit", "")) == "e0" and (
				(moment in ["roll", "reveal"] and str(event.kind) == "enemy_roll") or
				(moment == "power" and str(event.kind) == "enemy_ability") or
				(moment == "impact" and str(event.kind) == "enemy_move") or
				(moment in ["suspense", "miss"] and str(event.kind) == "enemy_roll" and int(event.roll_index) == 2) or
				(moment == "combo" and str(event.kind) == "enemy_ability" and bool(event.combo)))
			if caught:
				var delay: float = {"roll": 0.4, "reveal": 0.93, "power": 0.48, "impact": 0.12, "suspense": 1.2, "miss": 1.85, "combo": 0.3}.get(moment, 0.1)
				await create_timer(delay).timeout
				break
			await create_timer(maxf(0.02, float(event.get("duration", 0.1)))).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var capture: Image = root.get_texture().get_image()
	var sample: Image = capture.duplicate()
	sample.resize(16, 9)
	var lit: bool = false
	for x in range(16):
		for y in range(9):
			if sample.get_pixel(x, y).get_luminance() > 0.005:
				lit = true
	if not lit:
		printerr("Capture is black; check graphics-driver errors above.")
		screen.free()
		quit(1)
		return
	capture.save_png(path)
	print("Saved " + path)
	root.remove_child(screen)
	screen.free()
	quit()
