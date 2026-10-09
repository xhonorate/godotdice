class_name DeepComposer
extends RefCounted
## The music, written the way the sound bank writes a crack: from nothing.
##
## A piece in `score.gd` is a key, a mode, a tempo, a chord for every two bars and a seed. This
## writes it out as twenty-four bars that loop, cut into six layers of one arrangement:
##
##   bed     the pad and the drone: the chords, held. Always on.
##   pulse   the bass and a light hand on the drums: walking pace.
##   melody  the tune, with its echo and the odd glint of a bell.
##   drive   the fight: the full kit, an arpeggio running under the tune, the bass in eighths.
##   threat  an elite or a Warden: taiko and timpani, a roll and a cymbal swell into every
##           fourth bar, and a low brass "braam" where they land.
##   peril   a Warden's hall: a galloping string ostinato, the tune itself in the horns, brass
##           stabs and high tremolo strings.
##
## The layers are strips of exactly the same length and the score player starts them on the
## same sample, so turning one up or down never moves the beat or changes the tune: a fight
## comes in over the melody that was already playing and goes out again under it.
##
## Every note is written once and laid into its strip wherever it falls (a held chord comes
## round every few bars, a kick drum hundreds of times), and anything ringing past the end of
## the loop is laid into its start, so the seam is never heard. Writing a piece takes a few
## seconds, so it is done ahead of time: `tools/music_render.gd` writes them and the soundtrack
## editor bakes them to Ogg in audio/music, which is what the game plays. The score player
## writes a piece here, on its worker thread, only if it has not been baked.

const RATE: int = DeepSynth.RATE
const LAYERS: PackedStringArray = ["bed", "pulse", "melody", "drive", "threat", "peril"]
## How loud each layer is written, as its average level in decibels: the tune clearly on top,
## the fight just under it, the bed and the bass beneath. The boss layers are written loud,
## to be heard over a fight already at full rather than to thicken it: a Warden's hall should
## sound like something else has arrived.
const LOUDNESS: Array = [-26.0, -27.0, -22.5, -25.0, -24.0, -23.0]
const BED: int = 0
const PULSE: int = 1
const MELODY: int = 2
const DRIVE: int = 3
const THREAT: int = 4
const PERIL: int = 5
## The layers the whole piece is levelled by: everything short of a boss. The boss layers go
## on top of that, and the Music bus's limiter catches what they push past full.
const LEVELLED: int = 4

const MODES: Dictionary = {
	"ionian": [0, 2, 4, 5, 7, 9, 11], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11], "mixolydian": [0, 2, 4, 5, 7, 9, 10], "aeolian": [0, 2, 3, 5, 7, 8, 10],
	"locrian": [0, 1, 3, 5, 6, 8, 10], "harmonic": [0, 2, 3, 5, 7, 8, 11], "phrygian_dominant": [0, 1, 4, 5, 7, 8, 10],
}
const PITCHES: Dictionary = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
	"G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}

## Twelve two-bar phrases: a tune stated and stated again, a second strain, a breath; all of
## it once more, landing; a bridge on a third strain, and home. Ending on a landing is what
## lets the loop come round without a bump.
const PLAN: Array = ["A", "A2", "B", "ans", "A", "A2", "B2", "end", "C", "C2", "B", "end"]

## Drum parts, one bar each, in sixteenths: X an accent, x a hit, o a ghost. A kit says which
## of its drums plays each part; a fill takes over the last bar of every eight in a fight.
const GROOVES: Dictionary = {
	4: {
		"pulse": {"kick": "o.......o.......", "hat": "..o...o...o...o.", "perc": "x.........o....."},
		"drive": {"kick": "X......xX.....x.", "back": "....X.......X...", "hat": "x.o.x.o.x.o.x.ox", "perc": "......o.......o."},
		"fill": {"perc": "........x.x.xxxX", "back": "....X.......x.x."},
	},
	3: {
		"pulse": {"kick": "o...........", "hat": "..o...o...o.", "perc": "x.......o..."},
		"drive": {"kick": "X.......x...", "back": "....X...X...", "hat": "x.o.x.o.x.ox", "perc": "..........o."},
		"fill": {"perc": "......x.xxxX", "back": "....X...x.x."},
	},
}
const HITS: Dictionary = {"X": 1.0, "x": 0.72, "o": 0.4}
const KITS: Dictionary = {
	"frame": {"kick": "kick", "back": "tom", "hat": "shaker", "perc": "frame"},
	"drip": {"kick": "kick", "back": "rim", "hat": "shaker", "perc": "drip"},
	"glass": {"kick": "kick", "back": "snare", "hat": "tick", "perc": "tick_low"},
	"wood": {"kick": "kick", "back": "wood_low", "hat": "shaker", "perc": "wood"},
	"anvil": {"kick": "taiko", "back": "anvil", "hat": "hat", "perc": "tom"},
	"chime": {"kick": "kick", "back": "snare", "hat": "hat", "perc": "chime"},
	"void": {"kick": "thud", "back": "rim", "hat": "hat", "perc": "drip_low"},
	"hearth": {"kick": "kick", "back": "rim", "hat": "shaker", "perc": "wood"},
}

## Pieces kept written at once. A piece is about ten megabytes of strips; the one playing,
## the one fading out and the one most likely next are all that is ever wanted.
const KEEP: int = 3
## A cave's air loops every this many seconds. Drips and pebbles fall at random inside it, so
## nobody counts to twenty-four.
const AIR_SECONDS: float = 24.0

static var _pieces: Dictionary = {}
static var _recent: Array = []
static var _airs: Dictionary = {}
static var _shelf: Mutex = Mutex.new()
## Set when the game closes: a piece half written stops, and is not kept.
static var abandon: bool = false

# --- the shelf ---------------------------------------------------------------------------------

static func written(id: String) -> Array:
	## The piece's strips if they are written, without waiting; empty if they are not.
	_shelf.lock()
	var strips: Array = _pieces.get(id, [])
	if not strips.is_empty():
		_recent.erase(id)
		_recent.append(id)
	_shelf.unlock()
	return strips

static func piece(id: String) -> Array:
	## The piece's strips, written now if they have not been. One AudioStreamWAV per layer.
	var have: Array = written(id)
	if not have.is_empty():
		return have
	var spec: Dictionary = DeepScore.track(id)
	if spec.is_empty():
		return []
	var made: Array = write(spec)
	if made.is_empty():
		return []
	_shelf.lock()
	_pieces[id] = made
	_recent.erase(id)
	_recent.append(id)
	while _recent.size() > KEEP:
		_pieces.erase(_recent.pop_front())
	_shelf.unlock()
	return made

static func air_written(family: String) -> AudioStreamWAV:
	_shelf.lock()
	var have: AudioStreamWAV = _airs.get(family, null)
	_shelf.unlock()
	return have

static func air(family: String) -> AudioStreamWAV:
	var have: AudioStreamWAV = air_written(family)
	if have != null:
		return have
	var made: AudioStreamWAV = write_air(family)
	if made != null:
		_shelf.lock()
		_airs[family] = made
		_shelf.unlock()
	return made

static func forget() -> void:
	_shelf.lock()
	_pieces.clear()
	_recent.clear()
	_airs.clear()
	_shelf.unlock()

# --- writing a piece ---------------------------------------------------------------------------

static func plan(spec: Dictionary) -> Dictionary:
	## Everything about a piece that is arithmetic rather than sound: the grid, the key and
	## a chord for every phrase. The suites read it to check a piece is what it says.
	var meter: int = 3 if int(spec.get("meter", 4)) == 3 else 4
	var steps_bar: int = meter * 4
	var step: int = int(round(float(RATE) * 60.0 / float(spec.get("bpm", 90)) / 4.0))
	var bars: int = PLAN.size() * 2
	var chords: Array = []
	var verse: Array = spec.get("chords", [0, 5, 3, 4, 0, 5, 3, 4])
	var bridge: Array = spec.get("bridge", [3, 5, 3, 4])
	for i in range(8):
		chords.append(int(verse[i % verse.size()]))
	for i in range(4):
		chords.append(int(bridge[i % bridge.size()]))
	var pc: int = int(PITCHES.get(str(spec.get("key", "C")), 0))
	## The key note sits between A2 and G#3, so every key is about as deep as every other.
	var root: int = 45 + posmod(pc - 9, 12)
	return {"spec": spec, "meter": meter, "steps_bar": steps_bar, "step": step, "bars": bars,
		"total": bars * steps_bar * step, "chords": chords, "root": root,
		"scale": MODES.get(str(spec.get("mode", "aeolian")), MODES.aeolian),
		"layers": clampi(int(spec.get("layers", LAYERS.size())), 1, LAYERS.size())}

static func write(spec: Dictionary, record: Variant = null) -> Array:
	## The piece as its layers, levelled together so the whole of it peaks just under full.
	## Given an array as `record`, every note laid down is also listed in it, as
	## [layer, voice, midi, step, length in steps, level]: what the soundtrack editor draws
	## and exports as MIDI. A drum's voice is "drum:<part>:<drum>", and its midi is 0.
	var p: Dictionary = plan(spec)
	p.notes = {}
	p.record = record
	p.layer = 0
	p.rng = RandomNumberGenerator.new()
	p.rng.seed = int(spec.get("seed", 1)) * 7919 + 13
	var strips: Array = []
	for i in range(int(p.layers)):
		var strip := DeepSynth.new(0.01)
		strip.samples.resize(int(p.total))
		strip.samples.fill(0.0)
		strips.append(strip)
	for i in range(strips.size()):
		if abandon:
			return []
		p.layer = i
		match i:
			BED: _bed(p, strips[i])
			PULSE: _pulse(p, strips[i])
			MELODY: _melody(p, strips[i])
			DRIVE: _drive(p, strips[i])
			THREAT: _threat(p, strips[i])
			PERIL: _peril(p, strips[i])
	## Each layer is brought to its own loudness (the tune on top, the bed under it), then
	## the whole is turned down together if the loudest moment of a fight would clip. The boss
	## layers are left out of that: turning every layer down so a Warden's hall fits would
	## make every walk between fights quieter. Both are read at every fourth sample, which is
	## close enough with the soft knee on the way out.
	var total: int = int(p.total)
	var buffers: Array = strips.map(func(strip: DeepSynth) -> PackedFloat32Array: return strip.samples)
	var gains: Array = []
	for i in range(buffers.size()):
		var b: PackedFloat32Array = buffers[i]
		var power: float = 0.0
		for j in range(0, total, 4):
			power += b[j] * b[j]
		var rms: float = sqrt(power / float(maxi(1, total / 4)))
		gains.append(db_to_linear(float(LOUDNESS[i])) / maxf(rms, 0.00001))
	var loudest: float = 0.0
	for j in range(0, total, 4):
		var value: float = 0.0
		for i in range(mini(buffers.size(), LEVELLED)):
			value += buffers[i][j] * gains[i]
		loudest = maxf(loudest, absf(value))
	var fit: float = minf(1.0, 0.85 / maxf(loudest, 0.0001))
	var out: Array = []
	for i in range(strips.size()):
		out.append(strips[i].loop_stream(float(gains[i]) * fit))
	return out

static func tune(p: Dictionary) -> Array:
	## The melody as [step, length in steps, scale step above the key note], one per note,
	## across the whole loop. Three short motifs, drawn from the piece's seed, are placed on
	## each phrase's chord: the first and second strains and the bridge.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.spec.get("seed", 1)) * 104729 + 7
	var meter: int = int(p.meter)
	var steps_bar: int = int(p.steps_bar)
	var motifs: Dictionary = {"A": _motif(rng, meter, 0), "B": _motif(rng, meter, 2), "C": _motif(rng, meter, 3)}
	var out: Array = []
	var anchor: int = 4
	for slot in range(PLAN.size()):
		var kind: String = str(PLAN[slot])
		var chord: int = int(p.chords[slot])
		var at: int = slot * 2 * steps_bar
		if kind == "ans":
			## A breath: two long notes and room for the echo.
			var high: int = _home(_nearest_tone(anchor + 2, chord))
			out.append([at + 4, steps_bar - 4, high])
			out.append([at + steps_bar + 2, steps_bar - 4, _home(_nearest_tone(high - 2, chord))])
			continue
		var motif: Array = motifs.get(kind.left(1), motifs.A)
		var notes: Array = motif
		if kind == "end":
			notes = motif.filter(func(n: Array) -> bool: return int(n[0]) < steps_bar)
		var lift: int = 2 if kind.begins_with("C") else 0
		var start: int = _nearest_tone(anchor + lift, chord)
		var last: int = start
		for i in range(notes.size()):
			var n: Array = notes[i]
			var deg: int = start + int(n[2]) - int(motif[0][2])
			if int(n[0]) % (steps_bar if meter == 3 else 8) == 0:
				deg = _nearest_tone(deg, chord)
			if i == notes.size() - 1 and kind.ends_with("2"):
				deg = _nearest_root(deg, chord)
			deg = _home(deg)
			out.append([at + int(n[0]), int(n[1]), deg])
			last = deg
		if kind == "end":
			## The landing: the chord's own note, held across the second bar.
			last = _home(_nearest_root(last, chord))
			out.append([at + steps_bar, steps_bar - 2, last])
		anchor = clampi(int(round((4.0 + float(last)) * 0.5)), 1, 6)
	return out

static func _motif(rng: RandomNumberGenerator, meter: int, lift: int) -> Array:
	## Two bars of tune, [onset, length, height], starting on the downbeat and ending on a
	## held note. Mostly steps, now and then a leap; a rest or a long note for breath.
	var beats: int = meter * 2
	var notes: Array = []
	var height: int = lift
	var beat: int = 0
	while beat < beats:
		var onset: int = beat * 4
		if beat >= beats - 2:
			var hold: int = (beats - beat) * 4 - (2 if rng.randf() < 0.5 else 0)
			if not notes.is_empty():
				height = _wander(rng, height, lift)
			notes.append([onset, hold, height])
			break
		var roll: float = rng.randf()
		var cell: Array
		if beat == 0:
			cell = [[0, 4]] if roll < 0.4 else ([[0, 2], [2, 2]] if roll < 0.8 else [[0, 3], [3, 1]])
		elif roll < 0.3:
			cell = [[0, 4]]
		elif roll < 0.58:
			cell = [[0, 2], [2, 2]]
		elif roll < 0.7:
			cell = [[0, 3], [3, 1]]
		elif roll < 0.8:
			cell = []
		elif roll < 0.9 and beat + 1 < beats - 2:
			cell = [[0, 8]]
			beat += 1
		else:
			cell = [[2, 2]]
		for c in cell:
			if not notes.is_empty():
				height = _wander(rng, height, lift)
			notes.append([onset + int(c[0]), int(c[1]), height])
		beat += 1
	return notes

static func _wander(rng: RandomNumberGenerator, height: int, lift: int) -> int:
	var steps: Array = [-2, -1, -1, -1, 0, 1, 1, 1, 2, 2, 3, -3, 4]
	var next: int = height + int(steps[rng.randi() % steps.size()])
	return clampi(next, lift - 3, lift + 5)

static func _nearest_tone(deg: int, chord: int) -> int:
	## The note of the chord nearest a scale step, the lower on a tie.
	for distance in range(0, 4):
		for candidate in [deg - distance, deg + distance]:
			if posmod(candidate - chord, 7) in [0, 2, 4]:
				return candidate
	return deg

static func _nearest_root(deg: int, chord: int) -> int:
	for distance in range(0, 4):
		for candidate in [deg - distance, deg + distance]:
			if posmod(candidate - chord, 7) == 0:
				return candidate
	return deg

static func _home(deg: int) -> int:
	## Keep the tune in a singer's range: about an octave and a half around the key note.
	while deg > 9:
		deg -= 7
	while deg < -2:
		deg += 7
	return deg

static func lead_base(p: Dictionary) -> int:
	## The key note the tune is written from: around E3 to D#4, so the tune (which climbs an
	## octave and a half from it) peaks near G5 rather than C6, where a flute or a string turns
	## shrill. A fifth higher for a voice that rings (a bell, glass), which would be muddy
	## down there.
	return _fit(int(p.root), 52 + 7 * clampi(int(p.spec.get("lead_octave", 0)), 0, 1))

static func pitch(p: Dictionary, base: int, deg: int) -> int:
	## A scale step above (or below) a note, in the piece's mode, as a MIDI number.
	var scale: Array = p.scale
	return base + int(scale[posmod(deg, 7)]) + 12 * floori(float(deg) / 7.0)

static func _fit(midi: int, low: int) -> int:
	## The same note moved by octaves into the twelve semitones from `low`.
	return low + posmod(midi - low, 12)

static func hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)

# --- the layers --------------------------------------------------------------------------------

static func _bed(p: Dictionary, strip: DeepSynth) -> void:
	var steps_bar: int = int(p.steps_bar)
	var root: int = int(p.root)
	var pad: String = str(p.spec.get("pad", "pad_warm"))
	for slot in range(PLAN.size()):
		var chord: int = int(p.chords[slot])
		var at: int = slot * 2 * steps_bar
		var tones: Array = [chord, chord + 2, chord + 4]
		if bool(p.spec.get("sevenths", false)):
			tones.append(chord + 6)
		for deg in tones:
			_play(p, strip, pad, _fit(pitch(p, root, deg), root + 7), at, 2 * steps_bar, 0.5)
		_play(p, strip, pad, _fit(pitch(p, root, chord), root - 5), at, 2 * steps_bar, 0.32)
	if bool(p.spec.get("drone", true)):
		_hum(strip, hz(root - 12), 0.07, 3)
		_hum(strip, hz(root - 5), 0.035, 5)
		_mark(p, "drone", root - 12, 0, int(p.bars) * steps_bar, 0.07)
		_mark(p, "drone", root - 5, 0, int(p.bars) * steps_bar, 0.035)

static func _pulse(p: Dictionary, strip: DeepSynth) -> void:
	var steps_bar: int = int(p.steps_bar)
	var meter: int = int(p.meter)
	var root: int = int(p.root)
	var bass: String = str(p.spec.get("bass", "bass_sub"))
	var style: String = str(p.spec.get("bass_style", "walk"))
	for bar in range(int(p.bars)):
		var chord: int = int(p.chords[bar / 2])
		var low: int = _fit(pitch(p, root, chord), root - 15)
		var fifth: int = _fit(pitch(p, root, chord + 4), root - 15)
		var at: int = bar * steps_bar
		match style:
			"pedal":
				if bar % 2 == 0:
					_play(p, strip, bass, low, at, 2 * steps_bar - 1, 0.85)
			"syncop":
				if meter == 4:
					_play(p, strip, bass, low, at, 5, 0.85)
					_play(p, strip, bass, low, at + 6, 5, 0.7)
					_play(p, strip, bass, fifth, at + 12, 3, 0.65)
				else:
					_play(p, strip, bass, low, at, 5, 0.85)
					_play(p, strip, bass, fifth, at + 6, 3, 0.65)
					_play(p, strip, bass, low, at + 9, 3, 0.6)
			_:
				_play(p, strip, bass, low, at, 7, 0.85)
				_play(p, strip, bass, fifth, at + 8, steps_bar - 9, 0.7)
	_groove(p, strip, "pulse", 0.5)

static func _melody(p: Dictionary, strip: DeepSynth) -> void:
	var steps_bar: int = int(p.steps_bar)
	var root: int = int(p.root)
	var lead: String = str(p.spec.get("lead", "lead_pluck"))
	var base: int = lead_base(p)
	var rng: RandomNumberGenerator = p.rng
	for n in tune(p):
		var strong: bool = int(n[0]) % 4 == 0
		_play(p, strip, lead, pitch(p, base, int(n[2])), int(n[0]), int(n[1]), (0.62 if strong else 0.5) * rng.randf_range(0.9, 1.05))
	## A glint over each breath and each landing: three notes of the chord climbing from the
	## octave above middle C, high and soft but not shrill.
	for slot in range(PLAN.size()):
		if not str(PLAN[slot]) in ["ans", "end"]:
			continue
		var chord: int = int(p.chords[slot])
		var at: int = slot * 2 * steps_bar + steps_bar
		var lift: int = _fit(pitch(p, root, chord), 72) - pitch(p, root, chord)
		for i in range(3):
			_play(p, strip, "lead_bell", pitch(p, root, chord + 2 * i) + lift, at + 2 + 2 * i, 2, 0.14 - 0.03 * float(i))
	var echo: float = float(p.spec.get("echo", 0.22))
	if echo > 0.0:
		strip.echo_round(3 * int(p.step), echo, 3)

static func _drive(p: Dictionary, strip: DeepSynth) -> void:
	var steps_bar: int = int(p.steps_bar)
	var root: int = int(p.root)
	var arp: String = str(p.spec.get("arp", "lead_pluck"))
	var rate: int = clampi(int(p.spec.get("arp_rate", 2)), 1, 4)
	var bass: String = str(p.spec.get("bass", "bass_sub"))
	for bar in range(int(p.bars)):
		var chord: int = int(p.chords[bar / 2])
		var at: int = bar * steps_bar
		## The arpeggio climbs the chord and comes back down, an octave over the pads.
		var first: int = _fit(pitch(p, root, chord), root + 8)
		var lift: int = first - pitch(p, root, chord)
		var notes: Array = [first, pitch(p, root, chord + 2) + lift, pitch(p, root, chord + 4) + lift, pitch(p, root, chord + 7) + lift]
		var order: Array = [0, 1, 2, 3, 2, 1]
		var i: int = 0
		for s in range(0, steps_bar, rate):
			_play(p, strip, arp, notes[order[i % order.size()]], at + s, rate, 0.3 if s % 4 == 0 else 0.22)
			i += 1
		## The bass, an octave down, in short eighths.
		var low: int = _fit(pitch(p, root, chord), root - 20)
		for s in range(0, steps_bar, 2):
			_play(p, strip, bass, low, at + s, 1, 0.32 if s % 4 == 0 else 0.22)
	_groove(p, strip, "drive", 1.0)

static func _threat(p: Dictionary, strip: DeepSynth) -> void:
	## An elite or a Warden: the big drums. Taiko on the strong beats, timpani on the chord's
	## root under them, a roll building through every fourth bar into a cymbal swell, and a low
	## brass "braam" where the swell lands. Nothing here is a tune, so it goes under any piece.
	var steps_bar: int = int(p.steps_bar)
	var meter: int = int(p.meter)
	var root: int = int(p.root)
	var step: int = int(p.step)
	var taiko: Array = [[0, 1.0], [6, 0.55], [10, 0.75]] if meter == 4 else [[0, 1.0], [6, 0.6]]
	for bar in range(int(p.bars)):
		var chord: int = int(p.chords[bar / 2])
		var at: int = bar * steps_bar
		var drum_root: int = _fit(pitch(p, root, chord), root - 7)
		var drum_fifth: int = _fit(pitch(p, root, chord + 4), drum_root)
		for hit in taiko:
			_hit(p, strip, "boom", "taiko", at + int(hit[0]), 0.8 * float(hit[1]))
		_play(p, strip, "timpani", drum_root, at, 4, 0.7)
		_play(p, strip, "timpani", drum_fifth if meter == 4 else drum_root, at + 8, 4, 0.5 if meter == 4 else 0.4)
		if bar % 4 == 0:
			## The braam: low, wide and opening, where the swell crests.
			var low: int = _fit(pitch(p, root, chord), 38)
			_play(p, strip, "braam", low, at, steps_bar + steps_bar / 2, 0.6)
			_play(p, strip, "braam", _fit(pitch(p, root, chord + 4), low), at, steps_bar + steps_bar / 2, 0.42)
		if bar % 4 == 3:
			## The roll: sixteenths on the root through the second half of the bar, from a
			## murmur to a crack, under a cymbal swelling into the next four bars.
			var from: int = steps_bar / 2
			for s in range(from, steps_bar):
				_play(p, strip, "timpani", drum_root, at + s, 1, 0.18 + 0.45 * float(s - from) / float(maxi(1, steps_bar - from - 1)))
			var swell: PackedFloat32Array = _note(p, "swell", 0, 0, 0)
			strip.add(swell, (at + steps_bar) * step - int(1.45 * float(RATE)), 0.5)
			_mark(p, "drum:swell:swell", 0, (at + steps_bar) % (int(p.bars) * steps_bar), 1, 0.5)

static func _peril(p: Dictionary, strip: DeepSynth) -> void:
	## A Warden's hall. Strings gallop on the chord in sixteenths (long, short, short), the
	## piece's own tune comes back in the horns, broad and slow, brass stabs the downbeat, and
	## high strings tremble over all of it: the mine's music, under pressure.
	var steps_bar: int = int(p.steps_bar)
	var meter: int = int(p.meter)
	var root: int = int(p.root)
	for bar in range(int(p.bars)):
		var chord: int = int(p.chords[bar / 2])
		var at: int = bar * steps_bar
		var low: int = _fit(pitch(p, root, chord), root + 3)
		var fifth: int = _fit(pitch(p, root, chord + 4), low)
		var figure: Array = [low, low, fifth, low + 12] if meter == 4 else [low, fifth, low]
		for beat in range(meter):
			var s: int = at + beat * 4
			var note: int = int(figure[beat])
			_play(p, strip, "spiccato", note, s, 2, 0.44 if beat == 0 else 0.36)
			_play(p, strip, "spiccato", note, s + 2, 1, 0.26)
			_play(p, strip, "spiccato", note, s + 3, 1, 0.3)
		for k in [0, 2, 4]:
			var stab: int = _fit(pitch(p, root, chord + k), root + 7)
			_play(p, strip, "brass", stab, at, 2, 0.34)
			if meter == 4:
				_play(p, strip, "brass", stab, at + 6, 2, 0.22)
		if bar % 2 == 0:
			for deg in [chord + 2, chord + 4]:
				_play(p, strip, "strings", _fit(pitch(p, root, deg), root + 19), at, 2 * steps_bar, 0.24)
	## The horns: the notes of the tune that fall on a beat, held to the next and played broad,
	## in the tune's own octave (an octave down for a tune written high, for bells and glass).
	var horn_base: int = lead_base(p) - (12 if int(p.spec.get("lead_octave", 0)) == 1 else 0)
	for n in tune(p):
		if int(n[0]) % 4 == 0 and int(n[1]) >= 2:
			_play(p, strip, "horn", pitch(p, horn_base, int(n[2])), int(n[0]), mini(int(n[1]), 8), 0.5)

static func _hit(p: Dictionary, strip: DeepSynth, part: String, drum: String, at_step: int, level: float) -> void:
	strip.add(_note(p, drum, 0, 0, at_step % 2), at_step * int(p.step), level)
	_mark(p, "drum:%s:%s" % [part, drum], 0, at_step, 1, level)

static func _groove(p: Dictionary, strip: DeepSynth, part: String, level: float) -> void:
	var meter: int = int(p.meter)
	var steps_bar: int = int(p.steps_bar)
	var kit: Dictionary = KITS.get(str(p.spec.get("kit", "frame")), KITS.frame)
	var grooves: Dictionary = GROOVES[meter]
	var rng: RandomNumberGenerator = p.rng
	for bar in range(int(p.bars)):
		var lines: Dictionary = grooves[part].duplicate()
		if part == "drive" and bar % 8 == 7:
			lines.merge(grooves.fill, true)
		for role in lines:
			var line: String = str(lines[role])
			var drum: String = str(kit.get(role, ""))
			if drum.is_empty():
				continue
			for s in range(mini(line.length(), steps_bar)):
				var mark: String = line[s]
				if not HITS.has(mark):
					continue
				var hit: PackedFloat32Array = _note(p, drum, 0, 0, s % 2)
				var loud: float = level * float(HITS[mark]) * rng.randf_range(0.88, 1.0)
				strip.add(hit, (bar * steps_bar + s) * int(p.step), loud)
				_mark(p, "drum:%s:%s" % [role, drum], 0, bar * steps_bar + s, 1, loud)

static func _play(p: Dictionary, strip: DeepSynth, voice: String, midi: int, at_step: int, steps: int, level: float) -> void:
	strip.add(_note(p, voice, midi, maxi(1, steps), 0), at_step * int(p.step), level)
	_mark(p, voice, midi, at_step, maxi(1, steps), level)

static func _mark(p: Dictionary, voice: String, midi: int, at_step: int, steps: int, level: float) -> void:
	if p.get("record", null) is Array:
		p.record.append([int(p.layer), voice, midi, at_step, steps, snappedf(level, 0.001)])

static func _note(p: Dictionary, voice: String, midi: int, steps: int, take: int) -> PackedFloat32Array:
	## A note, written once per piece and laid down as often as it is played.
	var key: String = "%s:%d:%d:%d" % [voice, midi, steps, take]
	var have: Variant = p.notes.get(key, null)
	if have != null:
		return have
	var seconds: float = float(steps * int(p.step)) / float(RATE)
	var made: PackedFloat32Array = sound(voice, hz(midi), seconds, absi(hash(key)) | 1)
	p.notes[key] = made
	return made

static func sound(voice: String, freq: float, seconds: float, seed_value: int = 1) -> PackedFloat32Array:
	## One note of one instrument. The pads swell and hold, the tunes are struck or blown,
	## the drums ignore pitch and length altogether.
	var s: DeepSynth
	var ring: float
	match voice:
		"pad_warm":
			s = DeepSynth.new(seconds + 1.6, seed_value)
			s.voice(0.0, seconds, freq, 0.22, "saw", minf(0.9, seconds * 0.3), 1.5, 3, 11.0, maxf(520.0, freq * 2.2))
		"pad_glass":
			s = DeepSynth.new(seconds + 1.9, seed_value)
			s.voice(0.0, seconds, freq, 0.26, "sine", minf(0.8, seconds * 0.3), 1.8, 2, 7.0, 0.0, 0.0, 0.0, 0.12)
			s.voice(0.0, seconds, freq * 2.0, 0.05, "triangle", minf(1.2, seconds * 0.4), 1.8, 1, 0.0, 0.0, 0.0, 0.0, 0.3)
		"pad_choir":
			s = DeepSynth.new(seconds + 1.7, seed_value)
			s.voice(0.0, seconds, freq, 0.26, "triangle", minf(0.9, seconds * 0.35), 1.6, 3, 14.0, freq * 4.0, 0.0, 0.004)
		"pad_dark":
			s = DeepSynth.new(seconds + 2.0, seed_value)
			s.voice(0.0, seconds, freq, 0.26, "saw", minf(1.2, seconds * 0.4), 2.0, 2, 8.0, maxf(320.0, freq * 1.3))
		"bass_sub":
			s = DeepSynth.new(seconds + 0.2, seed_value)
			s.voice(0.0, seconds, freq, 0.5, "sine", 0.012, 0.15)
			s.voice(0.0, seconds, freq, 0.12, "triangle", 0.012, 0.12)
		"bass_pluck":
			ring = maxf(seconds, 0.5) + 0.3
			s = DeepSynth.new(ring, seed_value)
			s.pluck(0.0, ring, freq, 0.42, 0.994, 0.6)
			s.voice(0.0, seconds, freq, 0.26, "sine", 0.01, 0.2)
		"bass_saw":
			s = DeepSynth.new(seconds + 0.2, seed_value)
			s.voice(0.0, seconds, freq, 0.44, "saw", 0.01, 0.15, 2, 6.0, 210.0, 2.5)
		"lead_flute":
			## Breathed in rather than tongued, the breath itself low and soft: a wooden flute,
			## not a whistle.
			s = DeepSynth.new(seconds + 0.3, seed_value)
			s.voice(0.0, seconds, freq, 0.34, "sine", 0.09, 0.25, 1, 0.0, 0.0, 0.0, 0.005)
			s.voice(0.0, seconds, freq, 0.05, "triangle", 0.11, 0.2, 1, 0.0, freq * 3.0, 0.0, 0.005)
			s.noise(0.0, minf(seconds, 0.4) + 0.05, 0.018, 2000.0, 1100.0, 1.5, 0.05, 500.0)
		"lead_bell":
			ring = clampf(seconds * 1.6, 0.9, 2.6)
			s = DeepSynth.new(ring, seed_value)
			s.bell(0.0, ring, freq, 0.36, DeepSynth.CHIME_PARTIALS, 2.0)
		"lead_glass":
			s = DeepSynth.new(seconds + 1.3, seed_value)
			s.voice(0.0, seconds, freq, 0.3, "sine", 0.03, 1.2)
			s.tone(0.0, minf(1.2, seconds + 0.5), freq * 3.0, -1.0, 0.025, "sine", 3.0, 0.002)
			s.tone(0.0, 0.6, freq * 2.0, -1.0, 0.07, "sine", 3.0, 0.002)
		"lead_pluck":
			ring = clampf(seconds + 0.5, 0.6, 2.0)
			s = DeepSynth.new(ring, seed_value)
			## Thumbed, not picked: the string starts soft, so it rings without a click.
			s.pluck(0.0, ring, freq, 0.5, 0.996, 0.8)
			s.tone(0.0, ring * 0.7, freq, -1.0, 0.12, "sine", 2.0, 0.003)
		"lead_marimba":
			ring = clampf(seconds + 0.3, 0.5, 1.1)
			s = DeepSynth.new(ring, seed_value)
			s.tone(0.0, ring, freq, -1.0, 0.42, "sine", 3.4, 0.002)
			s.tone(0.0, ring * 0.3, freq * 3.93, -1.0, 0.08, "sine", 5.0, 0.001)
			if freq * 9.4 < DeepSynth.CEILING:
				s.tone(0.0, ring * 0.12, freq * 9.4, -1.0, 0.025, "sine", 6.0, 0.001)
		"lead_reed":
			s = DeepSynth.new(seconds + 0.25, seed_value)
			s.voice(0.0, seconds, freq, 0.26, "saw", 0.04, 0.2, 2, 5.0, minf(freq * 2.0, 1800.0), 1.2, 0.005)
		"brass":
			s = DeepSynth.new(seconds + 0.35, seed_value)
			s.voice(0.0, seconds, freq, 0.3, "saw", 0.06, 0.3, 3, 9.0, freq * 1.2, 3.0)
		"strings":
			s = DeepSynth.new(seconds + 0.7, seed_value)
			s.voice(0.0, seconds, freq, 0.22, "saw", 0.3, 0.6, 3, 12.0, freq * 3.0, 0.0, 0.0, 0.45)
		"spiccato":
			## Strings bounced off the bow: a hard start, gone almost at once.
			s = DeepSynth.new(seconds + 0.15, seed_value)
			s.voice(0.0, seconds * 0.8, freq, 0.3, "saw", 0.004, 0.07, 2, 7.0, minf(freq * 4.0, 3500.0))
			s.noise(0.0, 0.025, 0.05, 4000.0, 1500.0, 4.0, 0.001, 800.0)
		"horn":
			## Broad and round: a dark brass with a sine under it so it never turns to a buzz.
			s = DeepSynth.new(seconds + 0.4, seed_value)
			s.voice(0.0, seconds, freq, 0.3, "saw", 0.08, 0.3, 2, 6.0, minf(freq * 1.6, 1400.0), 1.5, 0.004)
			s.voice(0.0, seconds, freq, 0.12, "sine", 0.06, 0.3)
		"braam":
			## A low brass cluster blown hard: wide, detuned, its filter opening as it swells.
			s = DeepSynth.new(seconds + 0.9, seed_value)
			s.voice(0.0, seconds, freq, 0.36, "saw", 0.12, 0.9, 3, 16.0, freq * 1.4, 5.0)
			s.voice(0.0, seconds, freq * 2.0, 0.1, "saw", 0.2, 0.8, 2, 10.0, freq * 2.0, 3.0)
		"timpani":
			## A tuned kettle: the head's note and its fifth and octave, a slap of felt on top.
			ring = 1.6
			s = DeepSynth.new(ring, seed_value)
			s.tone(0.0, ring, freq * 1.01, freq, 0.62, "sine", 2.6, 0.003)
			s.tone(0.0, ring * 0.6, freq * 1.5, -1.0, 0.2, "sine", 3.4, 0.003)
			s.tone(0.0, ring * 0.4, freq * 1.99, -1.0, 0.1, "sine", 4.0, 0.002)
			s.noise(0.0, 0.08, 0.22, 1600.0, 300.0, 4.0)
		"kick":
			s = DeepSynth.new(0.4, seed_value)
			s.thump(0.0, 0.38, 105.0, 0.85, 0.12)
		"taiko":
			s = DeepSynth.new(0.75, seed_value)
			s.thump(0.0, 0.7, 82.0, 0.9, 0.35)
			s.noise(0.0, 0.25, 0.15, 900.0, 200.0, 3.0)
		"thud":
			s = DeepSynth.new(0.9, seed_value)
			s.tone(0.0, 0.85, 62.0, 38.0, 0.8, "sine", 2.4, 0.003)
			s.noise(0.0, 0.3, 0.12, 400.0, 120.0, 2.5)
		"tom":
			s = DeepSynth.new(0.45, seed_value)
			s.tone(0.0, 0.42, 150.0, 104.0, 0.6, "sine", 3.0, 0.002)
			s.noise(0.0, 0.08, 0.18, 2400.0, 600.0, 4.0)
		"frame":
			s = DeepSynth.new(0.35, seed_value)
			s.tone(0.0, 0.32, 210.0, 170.0, 0.45, "sine", 3.4, 0.002)
			s.noise(0.0, 0.05, 0.25, 3500.0, 900.0, 4.5)
		"snare":
			s = DeepSynth.new(0.24, seed_value)
			s.noise(0.0, 0.2, 0.4, 6000.0, 1800.0, 3.4, 0.001, 400.0)
			s.tone(0.0, 0.09, 210.0, 170.0, 0.3, "triangle", 4.5, 0.001)
		"rim":
			s = DeepSynth.new(0.1, seed_value)
			s.clack(0.0, 0.42, 1250.0)
		"hat":
			s = DeepSynth.new(0.08, seed_value)
			s.noise(0.0, 0.06, 0.45, 11000.0, 9000.0, 5.0, 0.0005, 3000.0)
		"shaker":
			s = DeepSynth.new(0.12, seed_value)
			s.noise(0.0, 0.1, 0.26, 9000.0, 6000.0, 3.2, 0.025, 3500.0)
		"tick":
			s = DeepSynth.new(0.3, seed_value)
			s.bell(0.0, 0.25, 3150.0, 0.2, DeepSynth.CHIME_PARTIALS, 4.0)
		"tick_low":
			s = DeepSynth.new(0.4, seed_value)
			s.bell(0.0, 0.35, 1580.0, 0.28, DeepSynth.CHIME_PARTIALS, 3.6)
		"wood":
			s = DeepSynth.new(0.12, seed_value)
			s.tone(0.0, 0.1, 880.0, 820.0, 0.5, "sine", 6.0, 0.001)
			s.tone(0.0, 0.05, 2400.0, -1.0, 0.12, "sine", 7.0, 0.001)
		"wood_low":
			s = DeepSynth.new(0.16, seed_value)
			s.tone(0.0, 0.14, 520.0, 480.0, 0.55, "sine", 5.5, 0.001)
			s.tone(0.0, 0.06, 1450.0, -1.0, 0.12, "sine", 7.0, 0.001)
		"anvil":
			s = DeepSynth.new(0.8, seed_value)
			s.bell(0.0, 0.75, 640.0, 0.34, DeepSynth.METAL_PARTIALS, 3.2)
			s.noise(0.0, 0.03, 0.2, 9000.0, 3000.0, 5.0)
		"chime":
			s = DeepSynth.new(1.0, seed_value)
			s.bell(0.0, 0.95, 1320.0, 0.22, DeepSynth.CHIME_PARTIALS, 2.8)
		"drip":
			s = DeepSynth.new(0.3, seed_value)
			s.tone(0.0, 0.09, 760.0, 1520.0, 0.34, "sine", 4.0, 0.001)
			s.tone(0.11, 0.06, 1500.0, 1900.0, 0.08, "sine", 4.0, 0.001)
		"drip_low":
			s = DeepSynth.new(0.35, seed_value)
			s.tone(0.0, 0.14, 380.0, 760.0, 0.4, "sine", 3.6, 0.001)
		"swell":
			s = DeepSynth.new(1.7, seed_value)
			s.noise(0.0, 1.65, 0.3, 2500.0, 9000.0, 6.0, 1.45, 1500.0)
		_:
			s = DeepSynth.new(maxf(seconds, 0.1), seed_value)
			s.tone(0.0, maxf(seconds, 0.1), freq, -1.0, 0.3, "triangle", 2.0)
	return s.samples

static func _hum(strip: DeepSynth, freq: float, amp: float, swells: int) -> void:
	## A note held for the whole loop, tuned so a whole number of its cycles fit in it and
	## breathing a whole number of times, so the loop comes round in the middle of a cycle
	## without a step.
	var total: int = strip.samples.size()
	var cycles: float = maxf(1.0, round(freq * float(total) / float(RATE)))
	var inc: float = TAU * cycles / float(total)
	var breath: float = TAU * float(maxi(1, swells)) / float(total)
	for i in range(total):
		strip.samples[i] += sin(inc * float(i)) * amp * (0.7 + 0.3 * cos(breath * float(i)))

# --- the air of a cave -------------------------------------------------------------------------

static func write_air(family: String) -> AudioStreamWAV:
	## The sound of the place itself, under the music: moving air, and whatever drips, falls,
	## bubbles or rings in it, scattered at random through a loop that folds onto itself.
	var room := DeepSynth.new(0.01, absi(hash(family)) | 1)
	var total: int = int(AIR_SECONDS * float(RATE))
	room.samples.resize(total)
	room.samples.fill(0.0)
	var rng: RandomNumberGenerator = room.rng
	match family:
		"galleries":
			_breath(room, 260.0, 0.22)
			_hum(room, 55.0, 0.035, 2)
			_scatter(room, "pebbles", 6)
			_scatter(room, "drip", 3)
			_scatter(room, "creak", 2)
			_scatter(room, "rumble", 1)
		"seeps":
			_breath(room, 420.0, 0.18)
			_breath(room, 6000.0, 0.035, 2500.0)
			_scatter(room, "drip", 16)
			_scatter(room, "drip_deep", 5)
		"crystal":
			_breath(room, 380.0, 0.16)
			_hum(room, 196.0, 0.025, 3)
			_hum(room, 197.3, 0.025, 2)
			_scatter(room, "tinkle", 11)
			_scatter(room, "drip", 3)
		"fungal":
			_breath(room, 240.0, 0.22)
			_hum(room, 49.0, 0.04, 2)
			_scatter(room, "bubble", 14)
			_scatter(room, "puff", 4)
			_scatter(room, "creak", 2)
		"magma":
			_breath(room, 180.0, 0.3)
			_scatter(room, "rumble", 2)
			_scatter(room, "pop", 10)
			_scatter(room, "crackle", 70)
			_scatter(room, "hiss", 2)
		"geode":
			_breath(room, 500.0, 0.14)
			for f in [110.0, 165.0, 220.0, 275.0]:
				_hum(room, f, 0.018, rng.randi_range(2, 4))
			_scatter(room, "tinkle", 8)
		"rift":
			_breath(room, 300.0, 0.2)
			_hum(room, 73.4, 0.04, 3)
			_hum(room, 75.1, 0.04, 2)
			_scatter(room, "whoosh", 3)
			_scatter(room, "whistle", 3)
			_scatter(room, "tinkle", 3)
		"workshop":
			_breath(room, 160.0, 0.18)
			_breath(room, 900.0, 0.05)
			_scatter(room, "crackle", 90)
			_scatter(room, "pop", 4)
			_scatter(room, "creak", 2)
		_:
			_breath(room, 260.0, 0.22)
	var loudest: float = room.peak()
	return room.loop_stream(0.6 / maxf(loudest, 0.0001))

static func _breath(room: DeepSynth, cutoff: float, amp: float, highpass: float = 0.0) -> void:
	## Moving air: noise through two low passes, its tail folded over its head so it loops.
	var total: int = room.samples.size()
	var fold: int = mini(int(1.5 * float(RATE)), total / 2)
	var a: float = clampf(TAU * cutoff / float(RATE), 0.0, 1.0)
	var h: float = clampf(TAU * highpass / float(RATE), 0.0, 1.0)
	var rng: RandomNumberGenerator = room.rng
	var air := PackedFloat32Array()
	air.resize(total + fold)
	var low_a: float = 0.0
	var low_b: float = 0.0
	var high: float = 0.0
	var power: float = 0.0
	for i in range(total + fold):
		low_a += (rng.randf() * 2.0 - 1.0 - low_a) * a
		low_b += (low_a - low_b) * a
		var value: float = low_b
		if highpass > 0.0:
			high += (value - high) * h
			value -= high
		air[i] = value
		power += value * value
	var level: float = amp / maxf(0.00001, sqrt(power / float(total + fold)))
	for i in range(fold):
		var t: float = float(i) / float(fold) * PI * 0.5
		air[i] = air[i] * sin(t) + air[total + i] * cos(t)
	for i in range(total):
		room.samples[i] += air[i] * level * 0.35

static func _scatter(room: DeepSynth, what: String, count: int) -> void:
	## Things that happen in the air now and then, anywhere in the loop.
	var rng: RandomNumberGenerator = room.rng
	var total: int = room.samples.size()
	for _i in range(count):
		var s: DeepSynth
		match what:
			"pebbles":
				s = DeepSynth.new(1.6, rng.randi() | 1)
				s.clatter(0.0, rng.randf_range(0.2, 0.5), 0.1, rng.randi_range(2, 5), 700.0)
				s.echoes(0.19, 0.35, 3)
			"drip":
				var f: float = rng.randf_range(650.0, 1400.0)
				s = DeepSynth.new(1.4, rng.randi() | 1)
				s.tone(0.0, 0.08, f, f * 1.9, rng.randf_range(0.08, 0.18), "sine", 4.0, 0.001)
				s.echoes(0.23, 0.4, 4)
			"drip_deep":
				var f: float = rng.randf_range(260.0, 420.0)
				s = DeepSynth.new(1.6, rng.randi() | 1)
				s.tone(0.0, 0.14, f, f * 1.7, 0.16, "sine", 3.4, 0.002)
				s.echoes(0.31, 0.4, 3)
			"creak":
				s = DeepSynth.new(1.0, rng.randi() | 1)
				s.voice(0.0, rng.randf_range(0.3, 0.6), rng.randf_range(70.0, 110.0), 0.07, "saw", 0.12, 0.2, 1, 0.0, 420.0, 0.0, 0.03)
			"rumble":
				s = DeepSynth.new(4.0, rng.randi() | 1)
				s.rumble(0.0, 3.6, 0.3)
			"tinkle":
				s = DeepSynth.new(2.4, rng.randi() | 1)
				s.bell(0.0, 1.8, rng.randf_range(2200.0, 5200.0), rng.randf_range(0.04, 0.09), DeepSynth.CHIME_PARTIALS, 2.0)
				s.echoes(0.31, 0.3, 2)
			"bubble":
				var f: float = rng.randf_range(140.0, 260.0)
				s = DeepSynth.new(0.3, rng.randi() | 1)
				s.tone(0.0, 0.12, f, f * 1.8, rng.randf_range(0.1, 0.22), "sine", 3.5, 0.004)
			"puff":
				s = DeepSynth.new(1.2, rng.randi() | 1)
				s.noise(0.0, 1.0, 0.1, 900.0, 400.0, 2.0, 0.3)
			"pop":
				s = DeepSynth.new(0.4, rng.randi() | 1)
				s.thump(0.0, 0.3, rng.randf_range(80.0, 120.0), 0.3, 0.4)
			"crackle":
				s = DeepSynth.new(0.03, rng.randi() | 1)
				s.noise(0.0, 0.012, rng.randf_range(0.03, 0.12), 7000.0, 3000.0, 5.0, 0.0005, 1500.0)
			"hiss":
				s = DeepSynth.new(1.6, rng.randi() | 1)
				s.noise(0.0, 1.5, 0.06, 7000.0, 5000.0, 1.5, 0.5, 3000.0)
			"whoosh":
				s = DeepSynth.new(2.6, rng.randi() | 1)
				s.noise(0.0, 2.5, 0.14, 300.0, 2600.0, 6.0, 2.2, 150.0)
			"whistle":
				s = DeepSynth.new(2.2, rng.randi() | 1)
				s.tone(0.0, 2.0, rng.randf_range(1100.0, 1500.0), rng.randf_range(600.0, 800.0), 0.035, "sine", 1.0, 0.5, 0.01, 4.5)
			_:
				continue
		room.add(s.samples, rng.randi_range(0, total - 1), 1.0)
