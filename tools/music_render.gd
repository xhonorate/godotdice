extends SceneTree
## Writes pieces of music out as WAV files to listen to outside the game, one file a layer.
## The layers are the same length and start together: lay them on top of each other in any
## audio editor to hear a fight (all of them) or a walk (bed, pulse, melody).
##   godot --headless --path . --script tools/music_render.gd -- build/music [piece ...]
## With no pieces named, writes every one in the score (about two minutes). `air:<family>`
## writes a cave's air instead (galleries, seeps, crystal, fungal, magma, geode, rift, workshop).

func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var out: String = str(args[0]) if args.size() > 0 else "build/music"
	var wanted: Array = args.slice(1) if args.size() > 1 else DeepScore.TRACKS.keys()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out))
	for id in wanted:
		var began: int = Time.get_ticks_msec()
		if str(id).begins_with("air:"):
			var air: AudioStreamWAV = DeepComposer.write_air(str(id).substr(4))
			air.save_to_wav("res://%s/%s.wav" % [out, str(id).replace(":", "_")])
			print("%-22s %4.1f s  written in %d ms" % [id, air.get_length(), Time.get_ticks_msec() - began])
			continue
		var spec: Dictionary = DeepScore.track(str(id))
		if spec.is_empty():
			printerr("No piece called %s" % id)
			continue
		var strips: Array = DeepComposer.write(spec)
		for i in range(strips.size()):
			strips[i].save_to_wav("res://%s/%s_%d_%s.wav" % [out, id, i, DeepComposer.LAYERS[i]])
		print("%-22s %4.1f s  %d layers  written in %d ms  (%s)" % [id, strips[0].get_length(), strips.size(), Time.get_ticks_msec() - began, spec.get("name", "")])
	quit(0)

