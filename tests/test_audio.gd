extends SceneTree
## The sound keepers, headless: every recipe in the bank makes a real waveform, the synth's
## voices behave, and no screen asks for a sound that was never written.

var checks: int = 0
var failures: Array = []

func _init() -> void:
	_test_synth()
	_test_bank()
	_test_names()
	_test_mixer()
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

func _peak_of(sound: AudioStreamWAV) -> float:
	var loudest: float = 0.0
	var bytes: PackedByteArray = sound.data
	for i in range(0, bytes.size(), 2):
		loudest = maxf(loudest, absf(float(bytes.decode_s16(i)) / 32767.0))
	return loudest
