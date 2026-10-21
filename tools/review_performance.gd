extends "res://tools/review_visual.gd"
## Rendered frame-time sampling; run alone, with no other Godot processes active.
## godot --path . --script tools/review_performance.gd -- [output_directory]
## Vsync is disabled in scratch settings. Battle is a stationary planning fixture.

var samples: Array = []

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	output = str(args[0]) if not args.is_empty() else "build/review-2026-10-19/performance"
	DirAccess.make_dir_recursive_absolute(output)
	DeepSaveStore.override_directory = "user://review_performance"
	var scratch := DeepSaveStore.new()
	for file in ["profile.json", "settings.json", "run.json"]:
		scratch.remove(file)
	app = load("res://view/app.gd").new()
	root.add_child(app)
	await process_frame
	root.size = Vector2i(1440, 810)
	app.settings.vsync = false
	app.settings.quality = 3
	app._apply_settings()
	await create_timer(8.0).timeout
	if args.size() > 1 and args[1] == "biomes":
		await _biomes()
		return
	await _sample("fresh_descend")
	_fill()
	app.profile.tray.clear()
	app._profile_changed()
	var opened := Time.get_ticks_usec()
	app.home.open("vault")
	var open_ms := float(Time.get_ticks_usec() - opened) / 1000.0
	print("VAULT_BUILD_MS ", open_ms)
	await create_timer(8.0).timeout
	await _sample("populated_vault")
	app.home.open("descend")
	app._depart(9001)
	app.session.paused = true
	var run: Dictionary = app.session.run
	run.depth = 3
	run.phase = "chamber"
	run.chamber = {"depth": 3, "settled": false}
	DeepDescent._start_fight(run, DeepDescent.streams_of(run), false, "")
	app.descent.show_state(run)
	await create_timer(8.0).timeout
	await _sample("quarry_battle_high")
	app.settings.quality = 1
	app._apply_settings()
	await create_timer(4.0).timeout
	await _sample("quarry_battle_low")
	app.settings.outlines = false
	app._apply_settings()
	await create_timer(3.0).timeout
	await _sample("quarry_battle_low_no_outlines")
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "gpu": RenderingServer.get_video_adapter_name(), "resolution": str(root.size), "vault_build_ms": open_ms, "samples": samples}, "\t"))
	app.queue_free()
	await process_frame
	await process_frame
	quit()

func _biomes() -> void:
	app._depart(9001)
	app.session.paused = true
	for mine in DeepContent.mines_in_order():
		var run: Dictionary = app.session.run
		run.mine = str(mine)
		run.depth = 3
		run.phase = "chamber"
		run.chamber = {"depth": 3, "settled": false}
		DeepDescent._start_fight(run, DeepDescent.streams_of(run), false, "")
		app.descent.show_state(run)
		await create_timer(4.0).timeout
		await _sample(str(mine).to_lower() + "_high")
	var file := FileAccess.open(output.path_join("biomes_metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "gpu": RenderingServer.get_video_adapter_name(), "resolution": str(root.size), "samples": samples}, "\t"))
	app.queue_free()
	await process_frame
	await process_frame
	quit()

func _sample(label: String) -> void:
	var frames: Array[float] = []
	var draws: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(240):
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - previous) / 1000.0)
		previous = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames.sort()
	draws.sort()
	var total: float = frames.reduce(func(sum: float, value: float) -> float: return sum + value, 0.0)
	var sample := {"scene": label, "frames": frames.size(), "mean_ms": total / frames.size(), "p50_ms": frames[120], "p95_ms": frames[228], "max_ms": frames.back(), "median_draws": draws[120], "memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
	samples.append(sample)
	print("PERFORMANCE ", JSON.stringify(sample))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
