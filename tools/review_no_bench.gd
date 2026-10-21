extends SceneTree
## Rendered regression for No Bench's optional respite. Uses no save store.
## Godot --path . --script tools/review_no_bench.gd

var failures: Array = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This check needs a window: headless deliberately omits the mine geometry.")
		quit(2)
		return
	root.size = Vector2i(1600, 900)
	var screen: Control = load("res://view/run/descent_screen.gd").new()
	screen.theme = DeepUi.theme()
	root.add_child(screen)
	await process_frame
	screen.bind("a", Callable())
	var state: Dictionary = DeepDescent.new_run(DeepEconomy.daily_config("2026-10-10", [{"id": "a", "name": "Audit"}], "no_bench_screen"))
	state.daily.mods = ["NO_BENCH"]
	state.depth = int(state.schedule.landings[0])
	DeepDescent._arrive_landing(state, DeepDescent.streams_of(state))
	state.players[0].haul = []
	state.players[0].ore = 0
	screen.show_state(state)
	await create_timer(1.5).timeout
	check(screen._stage.ways_live(), "No Bench opens the tunnel mouths without a paid respite")
	check("choose a tunnel" in screen._cross_sub.text, "No Bench explains the free way onward")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/review-2026-10-19"))
	root.get_texture().get_image().save_png("res://build/review-2026-10-19/no-bench.png")
	screen._open_landing("wish")
	check(not screen._stage.ways_live(), "the optional well page still pauses the ways down")
	screen._open_landing("")
	check(screen._stage.ways_live(), "returning from the well restores the free way down")
	var commands: Array = []
	screen.command.connect(func(command: Dictionary) -> void: commands.append(command))
	screen._choose_mouth(0)
	check(not commands.is_empty() and str(commands[0].get("kind", "")) == "choose" and str(commands[0].get("choice", "")) == "descend", "clicking a tunnel emits the descent command")
	if not commands.is_empty():
		check(bool(DeepDescent.command(state, "a", commands[0]).ok), "the displayed way down is accepted by the simulation")
	screen.queue_free()
	await process_frame
	await process_frame
	print("No Bench rendered check: 6 assertions, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
