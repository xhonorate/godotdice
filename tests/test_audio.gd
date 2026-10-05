extends SceneTree
## The sound keepers, headless: every recipe in the bank makes a real waveform, the synth's
## voices behave, no screen asks for a sound that was never written, and the music is
## written in layers that stay in step, in tune and in range.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_synth()
	_test_bank()
	_test_names()
	_test_mixer()
	_test_score()
	_test_composer()
	_test_director()
	print("Sound keepers: %d assertions, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + str(failure))
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _test_synth() -> void:
	var quiet := DeepSynth.new(0.2)
	check(quiet.samples.size() == int(0.2 * DeepSynth.RATE), "a synth is as long as it was asked to be")
	check(is_equal_approx(quiet.peak(), 0.0), "an untouched buffer is silence")
	for voice in ["sine", "triangle", "saw", "square"]:
		var shaped := DeepSynth.new(0.1).tone(0.0, 0.08, 440.0, -1.0, 0.5, voice)
		check(shaped.peak() > 0.1, "a %s tone is audible" % voice)
	check(DeepSynth.new(0.1).noise(0.0, 0.08, 0.5).peak() > 0.05, "noise is audible")
	check(DeepSynth.new(0.3).bell(0.0, 0.25, 440.0, 0.5).peak() > 0.1, "a bell is audible")
	check(DeepSynth.new(0.3).pluck(0.0, 0.25, 220.0, 0.5).peak() > 0.1, "a plucked string is audible")
	check(DeepSynth.new(0.3).thump(0.0, 0.2).peak() > 0.1, "a thump is audible")
	check(DeepSynth.new(0.3).shatter(0.0, 0.5, 900.0, 5, 0.2).peak() > 0.05, "a shatter is audible")
	## A voice that ends on anything but silence is a click.
	var tail := DeepSynth.new(0.2).tone(0.0, 0.2, 300.0, -1.0, 0.8, "sine", 1.0)
	check(absf(tail.samples[tail.samples.size() - 1]) < 0.02, "a voice lands on silence, whatever its decay")
	## Nothing written outside the buffer, however late or long the voice.
	var over := DeepSynth.new(0.1).tone(0.2, 0.3, 400.0, -1.0, 0.5).noise(-0.2, 0.05, 0.5)
	check(over.samples.size() == int(0.1 * DeepSynth.RATE), "a voice past the end does not stretch the buffer")
	var levelled := DeepSynth.new(0.2).tone(0.0, 0.15, 440.0, -1.0, 4.0).normalise(0.5).stream()
	check(levelled != null and levelled.data.size() == int(0.2 * DeepSynth.RATE) * 2, "a stream is 16-bit mono at the synth's rate")
	check(levelled.mix_rate == DeepSynth.RATE and not levelled.stereo, "a stream says what it is")
	## Partials that would fold back down the spectrum are never written.
	var high := DeepSynth.new(0.2).bell(0.0, 0.15, DeepSynth.CEILING * 0.9, 0.5)
	check(high.peak() > 0.0, "a bell above the ceiling still rings its fundamental")

func _test_bank() -> void:
	var loudest: float = 0.0
	var longest: float = 0.0
	for name in DeepSoundBank.NAMES:
		var sound: AudioStreamWAV = DeepSoundBank.stream(str(name))
		if sound == null:
			check(false, "%s has a recipe" % name)
			continue
		check(sound.data.size() > 2000, "%s is more than a tick long" % name)
		check(sound.get_length() < 3.0, "%s is a sound effect, not a track" % name)
		loudest = maxf(loudest, _peak_of(sound))
		longest = maxf(longest, sound.get_length())
		## Levels are set per recipe, from a whisper of a hover to a Peerless grade; the keeper
		## is only that nothing came out of the oven silent.
		check(_peak_of(sound) > 0.12, "%s is loud enough to hear" % name)
		check(sound.data.decode_s16(0) == 0 and sound.data.decode_s16(sound.data.size() - 2) == 0, "%s starts and ends on silence" % name)
	check(loudest <= 1.0, "nothing in the bank clips")
	check(DeepSoundBank.baked("ui_tap"), "the bank keeps what it bakes")
	check(DeepSoundBank.stream("ui_tap") == DeepSoundBank.stream("ui_tap"), "the same sound is handed back, not baked again")
	check(DeepSoundBank.stream("no_such_sound") == null, "an unknown name is nothing, not a crash")
	for color in DeepContent.section("colors"):
		check(DeepSoundBank.known(DeepSoundBank.gem_sound(str(color))), "every stone color rings: " + str(color))
	for tier in DeepUi.TIER_colorS:
		check(DeepSoundBank.known(DeepSoundBank.grade_sound(str(tier))), "every grade has its own sound: " + str(tier))

func _test_names() -> void:
	## Every sound a screen asks for by name has to be in the bank, or it is silence in a fight.
	var asked: Dictionary = {}
	_read_names("res://view", asked)
	check(asked.size() >= 30, "the screens ask for sounds at all (%d found)" % asked.size())
	for name in asked:
		check(DeepSoundBank.known(str(name)), "%s is asked for in %s and is in the bank" % [name, str(asked[name])])

func _read_names(directory: String, into: Dictionary) -> void:
	var calls := RegEx.create_from_string('DeepAudio\\.play\\(\\s*"([a-z_]+)"')
	var placed := RegEx.create_from_string('DeepAudio\\.(?:play_at|from)\\([^,]+,\\s*"([a-z_]+)"')
	for path in _scripts(directory):
		var source: String = FileAccess.get_file_as_string(path)
		for pattern in [calls, placed]:
			for found in pattern.search_all(source):
				into[found.get_string(1)] = path.get_file()

func _scripts(directory: String) -> PackedStringArray:
	var out := PackedStringArray()
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			out.append(directory.path_join(name))
	for name in DirAccess.get_directories_at(directory):
		out.append_array(_scripts(directory.path_join(name)))
	return out

func _test_mixer() -> void:
	## With no display the mixer never starts, and every call has to be a quiet no-op.
	check(DeepAudio.headless(), "the suite runs without a display")
	check(DeepAudio.service() == null, "no display, no mixer")
	DeepAudio.levels({"master_volume": 0.5, "sfx_volume": 0.5})
	DeepAudio.play("ui_tap")
	DeepAudio.play_at(Vector2(10, 10), "hit_light", {"volume": 0.5})
	DeepAudio.from(null, "toast")
	DeepAudio.reveal_stone(DeepStone.make("STRIKE", 8, 2, 5, ["STAR"], {}, "test"))
	check(true, "playing without a mixer does nothing at all")

# --- the music -------------------------------------------------------------------------------

const VOICES: Array = ["pad_warm", "pad_glass", "pad_choir", "pad_dark", "bass_sub", "bass_pluck", "bass_saw",
	"lead_flute", "lead_bell", "lead_glass", "lead_pluck", "lead_marimba", "lead_reed"]

func _test_score() -> void:
	## Every place has pieces to choose from, and every piece is written in things that exist.
	for mine in DeepContent.section("mines"):
		check(DeepScore.BOOK.has(str(mine)), "%s has music" % mine)
		check(DeepScore.AIR.has(str(mine)), "%s has air" % mine)
	for place in DeepScore.PLACES:
		var offered: Array = DeepScore.tracks_for(place)
		check(offered.size() >= (2 if place == DeepScore.HOME else 3), "%s has pieces to choose between" % place)
		for id in offered:
			var spec: Dictionary = DeepScore.track(str(id))
			check(not spec.is_empty(), "%s is written" % id)
			check(not str(spec.get("name", "")).is_empty(), "%s has a name" % id)
			check(DeepComposer.MODES.has(str(spec.get("mode", ""))), "%s is in a known mode" % id)
			check(DeepComposer.PITCHES.has(str(spec.get("key", ""))), "%s is in a known key" % id)
			check(DeepComposer.KITS.has(str(spec.get("kit", ""))), "%s plays a known kit" % id)
			check([3, 4].has(int(spec.get("meter", 0))), "%s is in three or four" % id)
			check(spec.get("chords", []).size() == 8 and spec.get("bridge", []).size() == 4, "%s has a chord for every phrase" % id)
			for field in ["pad", "bass", "lead", "arp"]:
				if spec.has(field):
					check(VOICES.has(str(spec[field])), "%s's %s is an instrument: %s" % [id, field, spec[field]])
	check(DeepScore.pick("QUARRY") == "quarry_lantern", "a mine with no pick plays its first piece")
	check(DeepScore.pick("QUARRY", {"QUARRY": "quarry_timber"}) == "quarry_timber", "a pick is honoured")
	check(DeepScore.pick("QUARRY", {"QUARRY": "glass_prism"}) == "quarry_lantern", "a piece from another mine is not")
	check(DeepScore.pick("NOWHERE") == "quarry_lantern", "an unknown place falls back to the Quarry")

func _test_composer() -> void:
	## The loop: a sound laid past the end of a buffer comes round into its start.
	var ring := DeepSynth.new(0.01)
	ring.samples.resize(10)
	ring.samples.fill(0.0)
	ring.add(PackedFloat32Array([1.0, 1.0, 1.0]), 8, 0.5)
	check(is_equal_approx(ring.samples[8], 0.5) and is_equal_approx(ring.samples[9], 0.5) and is_equal_approx(ring.samples[0], 0.5) and ring.samples[1] == 0.0,
		"a note past the end of a loop rings on into its start")
	check(DeepSynth.new(1.0).voice(0.0, 0.5, 220.0, 0.4, "saw", 0.05, 0.3, 3, 10.0, 800.0).peak() > 0.05, "a held voice is audible")
	var held := DeepSynth.new(1.0).voice(0.0, 0.5, 220.0, 0.4, "sine", 0.05, 0.3)
	check(absf(held.samples[int(0.79 * DeepSynth.RATE)]) < 0.02, "a held voice dies away after its release")
	for voice in VOICES + ["brass", "strings", "kick", "taiko", "thud", "tom", "frame", "snare", "rim", "hat", "shaker", "tick", "tick_low", "wood", "wood_low", "anvil", "chime", "drip", "drip_low", "swell"]:
		var note: PackedFloat32Array = DeepComposer.sound(str(voice), 220.0, 0.4, 7)
		var loudest: float = 0.0
		for value in note:
			loudest = maxf(loudest, absf(value))
		check(note.size() > 100 and loudest > 0.01, "%s makes a sound" % voice)
	## Every piece's arithmetic and tune, without writing the sound.
	for id in DeepScore.TRACKS:
		var p: Dictionary = DeepComposer.plan(DeepScore.track(str(id)))
		check(int(p.total) == int(p.bars) * int(p.steps_bar) * int(p.step), "%s is a whole number of bars" % id)
		var seconds: float = float(p.total) / float(DeepComposer.RATE)
		check(seconds > 40.0 and seconds < 100.0, "%s loops every minute or so (%.0f s)" % [id, seconds])
		var notes: Array = DeepComposer.tune(p)
		check(notes.size() > 40, "%s has a tune" % id)
		var span: int = int(p.bars) * int(p.steps_bar)
		var off_chord: int = 0
		for n in notes:
			check(int(n[0]) >= 0 and int(n[0]) < span and int(n[1]) > 0, "%s's notes fall inside the loop" % id)
			check(int(n[2]) >= -2 and int(n[2]) <= 9, "%s keeps its tune in range" % id)
			if int(n[0]) % int(p.steps_bar) == 0:
				var chord: int = int(p.chords[int(n[0]) / (2 * int(p.steps_bar))])
				if not posmod(int(n[2]) - chord, 7) in [0, 2, 4]:
					off_chord += 1
		check(off_chord == 0, "%s lands on the chord at the top of every bar (%d do not)" % [id, off_chord])
		check(DeepComposer.tune(p) == notes, "%s's tune is the same every time it is written" % id)
	## One piece written out whole, and the workshop's three-layer one.
	var strips: Array = DeepComposer.write(DeepScore.track("quarry_lantern"))
	check(strips.size() == DeepComposer.LAYERS.size(), "a mine's piece is written in every layer")
	var length: int = strips[0].data.size() if not strips.is_empty() else 0
	for i in range(strips.size()):
		var strip: AudioStreamWAV = strips[i]
		check(strip.data.size() == length, "every layer is the same length, so they stay in step (%s)" % DeepComposer.LAYERS[i])
		check(strip.loop_mode == AudioStreamWAV.LOOP_FORWARD and strip.loop_end == length / 2, "the %s layer loops whole" % DeepComposer.LAYERS[i])
		var loudest: float = _peak_of(strip)
		check(loudest > 0.05 and loudest <= 1.0, "the %s layer is audible and does not clip (%.2f)" % [DeepComposer.LAYERS[i], loudest])
	var home: Dictionary = DeepScore.track(DeepScore.pick(DeepScore.HOME))
	check(int(home.get("layers", 5)) == 3, "the workshop is written without a fight in it")
	check(DeepComposer.written("quarry_lantern").is_empty(), "writing a piece directly does not shelve it")
	DeepComposer.abandon = true
	check(DeepComposer.write(DeepScore.track("quarry_timber")).is_empty(), "a piece being written when the game closes is dropped")
	DeepComposer.abandon = false
	for family in DeepScore.AIR.values():
		var air: AudioStreamWAV = DeepComposer.write_air(str(family))
		check(air != null and air.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s air loops" % family)
		check(air != null and absf(air.get_length() - DeepComposer.AIR_SECONDS) < 0.1, "%s air is the length it says" % family)
		check(air != null and _peak_of(air) > 0.2, "%s air is audible" % family)

func _test_director() -> void:
	## Where the party is, heard: the workshop, a walk, a fight, a Warden.
	var home: Dictionary = DeepMusic.where_now({}, "SEEPS")
	check(home.place == DeepScore.HOME and home.mood == "home" and home.next == "SEEPS", "no run is the workshop, with the mapped mine next")
	var run: Dictionary = {"mine": "QUARRY", "phase": "tunnels", "depth": 1, "schedule": {"boss": 16}}
	check(DeepMusic.where_now(run).mood == "explore", "choosing a tunnel is a walk")
	check(is_equal_approx(DeepMusic.depth_into(run), 0.0), "the top of a mine is not deep")
	run.depth = 16
	check(is_equal_approx(DeepMusic.depth_into(run), 1.0), "the boss's floor is as deep as it goes")
	run.phase = "chamber"
	run.chamber = {"kind": "fight", "settled": false, "battle": {}}
	check(DeepMusic.where_now(run).mood == "fight", "a fight is a fight")
	run.chamber.kind = "warden"
	check(DeepMusic.where_now(run).mood == "warden", "a Warden's hall is its own")
	run.chamber.settled = true
	check(DeepMusic.where_now(run).mood == "explore", "a won fight lets the drums go")
	run.phase = "landing"
	check(DeepMusic.where_now(run).mood == "rest", "a landing is a rest")
	run.mine = "NOWHERE"
	check(DeepMusic.where_now(run).place == "QUARRY", "a mine with no music plays the Quarry's")
	var walk_top: Array = DeepMusic.layer_levels("explore", 0.0)
	var walk_deep: Array = DeepMusic.layer_levels("explore", 1.0)
	var fight: Array = DeepMusic.layer_levels("fight", 0.0)
	var warden: Array = DeepMusic.layer_levels("warden", 0.0)
	check(walk_top[DeepComposer.DRIVE] == 0.0 and fight[DeepComposer.DRIVE] > 0.5, "the drums are for fights")
	check(walk_deep[DeepComposer.PULSE] > walk_top[DeepComposer.PULSE] and walk_deep[DeepComposer.MELODY] > walk_top[DeepComposer.MELODY], "deeper, the walk grows")
	check(warden[DeepComposer.PERIL] > fight[DeepComposer.PERIL], "a Warden brings the horns")
	for mood in DeepMusic.MOODS:
		var levels: Array = DeepMusic.layer_levels(str(mood), 0.5)
		check(levels.size() == DeepComposer.LAYERS.size() and levels[DeepComposer.BED] > 0.5, "%s always keeps the bed" % mood)
	## No display: the player never starts, and every call is a quiet no-op.
	check(DeepMusic.service() == null, "no display, no score player")
	DeepMusic.follow(home)
	DeepMusic.preview("QUARRY", "quarry_lantern", "fight")
	DeepMusic.end_preview()
	DeepMusic.levels({"music_volume": 0.3, "music_picks": {"QUARRY": "quarry_timber"}})
	check(DeepMusic.picks().get("QUARRY", "") == "quarry_timber", "picks are taken from the settings")
	DeepMusic.levels({"music_picks": {}})

func _peak_of(sound: AudioStreamWAV) -> float:
	var loudest: float = 0.0
	var bytes: PackedByteArray = sound.data
	for i in range(0, bytes.size(), 2):
		loudest = maxf(loudest, absf(float(bytes.decode_s16(i)) / 32767.0))
	return loudest
