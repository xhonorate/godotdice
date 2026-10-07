extends SceneTree
## Writes pieces of music out as WAV files, one file a layer, with every note in them listed in
## notes.json beside them. The layers are the same length and start together: lay them on top
## of each other in any audio editor to hear a fight (all of them) or a walk (bed, pulse, melody).
##   godot --headless --path . --script tools/music_render.gd -- build/music [piece ...]
## With no pieces named, writes every one in the score (about two minutes). A piece is written
## to <out>/<id>/<n>_<layer>.wav. `<id>=<file.json>` writes a spec from that file instead of the
## score's (the soundtrack editor's drafts). `air:<family>` writes a cave's air to
## <out>/air/<family>.wav (galleries, seeps, crystal, fungal, magma, geode, rift, workshop).
##
## These are the raw renders. The game plays the Ogg files baked from them into audio/music:
## see `tools/data-browser/music.mjs`.

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var out: String = str(args[0]) if args.size() > 0 else "build/music"
	if not out.is_absolute_path():
		out = ProjectSettings.globalize_path("res://" + out)
	var wanted: Array = args.slice(1) if args.size() > 1 else DeepScore.TRACKS.keys()
	var failed: bool = false
	for job in wanted:
		var began: int = Time.get_ticks_msec()
		var id: String = str(job)
		if id.begins_with("air:"):
			var family: String = id.substr(4)
			DirAccess.make_dir_recursive_absolute(out.path_join("air"))
			var air: AudioStreamWAV = DeepComposer.write_air(family)
			air.save_to_wav(out.path_join("air").path_join(family + ".wav"))
			print("%-22s %4.1f s  written in %d ms" % [id, air.get_length(), Time.get_ticks_msec() - began])
			continue
		var spec: Dictionary = DeepScore.track(id)
		if id.contains("="):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(id.get_slice("=", 1)))
			id = id.get_slice("=", 0)
			spec = DeepScore.whole(parsed) if parsed is Dictionary else {}
		if spec.is_empty():
			printerr("No piece called %s" % id)
			failed = true
			continue
		var notes: Array = []
		var strips: Array = DeepComposer.write(spec, notes)
		var folder: String = out.path_join(id)
		DirAccess.make_dir_recursive_absolute(folder)
		for i in range(strips.size()):
			strips[i].save_to_wav(folder.path_join("%d_%s.wav" % [i, DeepComposer.LAYERS[i]]))
		var p: Dictionary = DeepComposer.plan(spec)
		var record: Dictionary = {"bpm": spec.get("bpm", 90), "meter": p.meter, "steps_bar": p.steps_bar, "bars": p.bars,
			"step_samples": p.step, "rate": DeepComposer.RATE, "total_samples": p.total, "root": p.root,
			"chords": p.chords, "plan": DeepComposer.PLAN, "layers": Array(DeepComposer.LAYERS).slice(0, strips.size()), "notes": notes}
		var file := FileAccess.open(folder.path_join("notes.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(record))
		file.close()
		print("%-22s %4.1f s  %d layers  %d notes  written in %d ms  (%s)" % [id, strips[0].get_length(), strips.size(), notes.size(), Time.get_ticks_msec() - began, spec.get("name", "")])
	quit(1 if failed else 0)
