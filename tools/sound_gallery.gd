extends SceneTree
## Plays the sound bank, one sound at a time, and says what each one cost.
##   godot --path . --script tools/sound_gallery.gd -- [filter] [gap seconds]
## A filter plays only the names containing it: `gem`, `ui`, `grade`, `hit`.
## Needs a window and a sound card: this one is not headless.

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var filter: String = str(args[0]) if args.size() > 0 else ""
	var gap: float = float(args[1]) if args.size() > 1 else 0.0
	if DisplayServer.get_name() == "headless":
		print("The gallery needs a window and a sound card; drop --headless.")
		quit(1)
		return
	root.size = Vector2i(640, 360)
	var mixer: DeepAudio = DeepAudio.start(root, {"master_volume": 1.0, "sfx_volume": 1.0})
	await process_frame
	print("Bus: %s at index %d" % [DeepAudio.BUS, AudioServer.get_bus_index(DeepAudio.BUS)])
	var wanted: Array = []
	for name in DeepSoundBank.NAMES:
		if filter.is_empty() or str(name).contains(filter):
			wanted.append(str(name))
	if wanted.is_empty():
		print("Nothing matches '%s'." % filter)
		quit(1)
		return
	print("Playing %d of %d sounds.\n" % [wanted.size(), DeepSoundBank.NAMES.size()])
	var total: int = 0
	for name in wanted:
		var began: int = Time.get_ticks_usec()
		var sound: AudioStreamWAV = DeepSoundBank.stream(name)
		var baked: int = Time.get_ticks_usec() - began
		total += baked
		if sound == null:
			printerr("FAIL: %s has no recipe" % name)
			continue
		DeepAudio.play(name, {"gap": 0.0, "vary": 0.0})
		print("%-16s %5.2fs  %6.1f kB  %s" % [name, sound.get_length(), float(sound.data.size()) / 1024.0,
			"baked in %.0f ms" % (float(baked) / 1000.0) if baked > 2000 else "ready"])
		await create_timer(maxf(sound.get_length() + 0.12, gap)).timeout
	print("\nBaking cost this run: %.0f ms. The game bakes the whole bank on a worker thread at boot." % (float(total) / 1000.0))
	if mixer != null:
		print("Voices: %d flat, %d placed." % [DeepAudio.FLAT_VOICES, DeepAudio.PLACED_VOICES])
	await create_timer(0.4).timeout
	quit(0)
