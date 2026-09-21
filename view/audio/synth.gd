class_name DeepSynth
extends RefCounted
## Sound, cut from nothing.
##
## There is not one audio file in this project. Stones are geometry, icons are drawn, and the
## sounds are written sample by sample: a buffer of floats that voices are added into — a
## struck bell, a burst of filtered noise, a sweeping tone, a plucked string, a rock falling —
## and then baked into the 16-bit stream the mixer plays.
##
## Every voice returns the synth, so a recipe in `sound_bank.gd` reads as the list of things
## you would hear, in the order you would hear them. Nothing here touches the display, and the
## only randomness is this object's own, so the whole bank can be baked on a worker thread
## while the workshop is being looked at, and checked headless in the suites.
##
## The inner loops are written for speed, not for looks: every envelope is a multiply, every
## frequency glide is an increment, and nothing calls a function per sample. The bank is 69
## sounds and it has to be ready before the player reaches the first fight.

## 12 kHz of bandwidth is more than any of these sounds needs. The mixer resamples.
const RATE: int = 24000
## Partials above this are not written: they would fold back down the spectrum as a whistle.
const CEILING: float = float(RATE) * 0.45

const SINE: int = 0
const TRIANGLE: int = 1
const SAW: int = 2
const SQUARE: int = 3
const SHAPES: Dictionary = {"sine": SINE, "triangle": TRIANGLE, "saw": SAW, "square": SQUARE}

## The partials of a struck bell: inharmonic, which is what makes it a bell and not an organ.
const BELL_PARTIALS: Array = [1.0, 2.76, 5.4, 8.93]
## A tube or a chime: near-harmonic, warmer and more musical than a bell.
const CHIME_PARTIALS: Array = [1.0, 2.0, 3.01, 4.17]
## Struck metal: dense and clangorous.
const METAL_PARTIALS: Array = [1.0, 1.51, 2.31, 3.37, 4.61]

var samples: PackedFloat32Array
## Its own, so two threads never draw from the same stream of numbers.
var rng: RandomNumberGenerator

var _headroom: float = 0.0

func _init(seconds: float = 0.5, seed_value: int = 0) -> void:
	samples = PackedFloat32Array()
	samples.resize(maxi(8, int(seconds * float(RATE))))
	rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value

func length() -> float:
	return float(samples.size()) / float(RATE)

func peak() -> float:
	var loudest: float = 0.0
	for value in samples:
		loudest = maxf(loudest, absf(value))
	return loudest

# --- voices ------------------------------------------------------------------------------------

func tone(at: float, seconds: float, from_hz: float, to_hz: float = -1.0, amp: float = 0.4,
		shape: String = "sine", curve: float = 3.0, attack: float = 0.004, wobble: float = 0.0,
		wobble_hz: float = 6.0) -> DeepSynth:
	## One oscillator gliding from one pitch to another under a struck envelope. `curve` is how
	## fast it dies: 1 is a slow fade, 6 is a tick. `wobble` bends the pitch while it sounds.
	var start: int = maxi(0, int(at * float(RATE)))
	var count: int = int(seconds * float(RATE))
	var limit: int = mini(count, samples.size() - start)
	if count <= 0 or limit <= 0:
		return self
	var target: float = to_hz if to_hz > 0.0 else from_hz
	var wave: int = int(SHAPES.get(shape, SINE))
	var phase: float = 0.0
	var inc: float = TAU * from_hz / float(RATE)
	var inc_step: float = TAU * (target - from_hz) / float(RATE) / float(count)
	var wobble_inc: float = TAU * wobble_hz / float(RATE)
	var wobble_phase: float = 0.0
	## Linear in, exponential out, landing exactly on silence so no voice ends on a step.
	var rise: int = clampi(int(attack * float(RATE)), 1, maxi(1, count - 1))
	var fall: float = curve * 2.6
	var tail: float = exp(-fall)
	var span: float = 1.0 / maxf(0.0001, 1.0 - tail)
	var decay_step: float = exp(-fall / float(maxi(1, count - rise)))
	var decay: float = 1.0 / decay_step
	var rise_step: float = 1.0 / float(rise)
	for i in range(limit):
		var envelope: float
		if i < rise:
			envelope = float(i) * rise_step
		else:
			decay *= decay_step
			envelope = (decay - tail) * span
		var bend: float = inc
		if wobble > 0.0:
			wobble_phase += wobble_inc
			bend += inc * wobble * sin(wobble_phase)
		phase += bend
		inc += inc_step
		var value: float
		if wave == SINE:
			value = sin(phase)
		elif wave == TRIANGLE:
			value = asin(sin(phase)) * 0.6366
		elif wave == SAW:
			value = fmod(phase, TAU) * 0.3183 - 1.0
		else:
			value = 1.0 if sin(phase) >= 0.0 else -1.0
		samples[start + i] += value * amp * envelope
	return self

func bell(at: float, seconds: float, hz: float, amp: float = 0.4, partials: Array = BELL_PARTIALS,
		curve: float = 2.6, detune: float = 0.0) -> DeepSynth:
	## A struck body: every partial is quieter and dies faster than the one below it, which is
	## what a real stone or bar does. `detune` beats a second copy against the first.
	for i in range(partials.size()):
		var ratio: float = float(partials[i])
		if hz * ratio > CEILING:
			break
		var voice: float = amp / (1.0 + float(i) * 1.35)
		tone(at, seconds / (1.0 + float(i) * 0.45), hz * ratio, -1.0, voice, "sine", curve, 0.002)
		if detune > 0.0:
			tone(at, seconds / (1.0 + float(i) * 0.45), hz * ratio * (1.0 + detune), -1.0, voice * 0.7, "sine", curve, 0.002)
	return self

func noise(at: float, seconds: float, amp: float = 0.3, cut_from: float = 6000.0, cut_to: float = 1200.0,
		curve: float = 3.0, attack: float = 0.002, highpass: float = 0.0) -> DeepSynth:
	## Air, rock and impact: white noise dragged through a one-pole low pass whose corner
	## sweeps, which is every whoosh, crack and crumble in the game.
	var start: int = maxi(0, int(at * float(RATE)))
	var count: int = int(seconds * float(RATE))
	var limit: int = mini(count, samples.size() - start)
	if count <= 0 or limit <= 0:
		return self
	var corner: float = clampf(TAU * cut_from / float(RATE), 0.0, 1.0)
	var corner_step: float = (clampf(TAU * cut_to / float(RATE), 0.0, 1.0) - corner) / float(count)
	var high_a: float = clampf(TAU * highpass / float(RATE), 0.0, 1.0)
	var low: float = 0.0
	var high: float = 0.0
	var rise: int = clampi(int(attack * float(RATE)), 1, maxi(1, count - 1))
	var fall: float = curve * 2.6
	var tail: float = exp(-fall)
	var span: float = 1.0 / maxf(0.0001, 1.0 - tail)
	var decay_step: float = exp(-fall / float(maxi(1, count - rise)))
	var decay: float = 1.0 / decay_step
	var rise_step: float = 1.0 / float(rise)
	var cutting: bool = highpass > 0.0
	for i in range(limit):
		var envelope: float
		if i < rise:
			envelope = float(i) * rise_step
		else:
			decay *= decay_step
			envelope = (decay - tail) * span
		low += (rng.randf() * 2.0 - 1.0 - low) * corner
		corner += corner_step
		var value: float = low
		if cutting:
			high += (value - high) * high_a
			value -= high
		samples[start + i] += value * amp * envelope
	return self

func pluck(at: float, seconds: float, hz: float, amp: float = 0.4, damping: float = 0.996) -> DeepSynth:
	## A string or a crystal shard: noise trapped in a ring one wavelength long, averaged a
	## little smoother on every pass. Karplus and Strong, 1983, and still the cheapest
	## convincing struck string there is.
	var start: int = maxi(0, int(at * float(RATE)))
	var count: int = int(seconds * float(RATE))
	var limit: int = mini(count, samples.size() - start)
	var ring_size: int = maxi(2, int(float(RATE) / maxf(hz, 20.0)))
	if count <= 0 or limit <= 0:
		return self
	var ring: PackedFloat32Array = PackedFloat32Array()
	ring.resize(ring_size)
	for i in range(ring_size):
		ring[i] = rng.randf() * 2.0 - 1.0
	var cursor: int = 0
	var decay_step: float = exp(-3.6 / float(limit))
	var decay: float = 1.0
	for i in range(limit):
		var value: float = ring[cursor]
		var next: int = (cursor + 1) % ring_size
		ring[cursor] = (value + ring[next]) * 0.5 * damping
		cursor = next
		decay *= decay_step
		samples[start + i] += value * amp * decay
	return self

func thump(at: float, seconds: float, hz: float = 150.0, amp: float = 0.6, body: float = 0.35) -> DeepSynth:
	## The weight under a blow: a sine dropping to the floor, with a little grit on the front.
	tone(at, seconds, hz, hz * 0.28, amp, "sine", 3.2, 0.001)
	if body > 0.0:
		noise(at, seconds * 0.4, amp * body, 2200.0, 300.0, 4.0)
	return self

func clack(at: float, amp: float = 0.35, hz: float = 900.0) -> DeepSynth:
	## Something small and hard landing on something hard: a die, a stone, a button.
	noise(at, 0.018, amp, 9000.0, 2400.0, 5.0, 0.0006)
	tone(at, 0.035, hz, hz * 0.55, amp * 0.5, "triangle", 5.0, 0.001)
	return self

func whoosh(at: float, seconds: float, amp: float = 0.25, from_hz: float = 400.0, to_hz: float = 2600.0) -> DeepSynth:
	## Air moving: a band of noise sliding up or down, cut off at both ends.
	noise(at, seconds, amp, from_hz * 2.4, to_hz * 2.4, 1.4, seconds * 0.35, from_hz * 0.7)
	return self

func rumble(at: float, seconds: float, amp: float = 0.4) -> DeepSynth:
	## The mountain overhead, felt more than heard.
	noise(at, seconds, amp, 180.0, 70.0, 1.2, seconds * 0.3)
	tone(at, seconds, 44.0, 31.0, amp * 0.7, "sine", 1.3, seconds * 0.25)
	return self

func shatter(at: float, amp: float = 0.4, hz: float = 1400.0, shards: int = 9, spread: float = 0.45) -> DeepSynth:
	## Something crystalline coming apart: the crack, then the pieces falling.
	noise(at, 0.09, amp, 11000.0, 2000.0, 4.0, 0.0008)
	for i in range(shards):
		var when: float = at + rng.randf() * spread
		var pitch: float = hz * rng.randf_range(0.6, 2.4)
		bell(when, rng.randf_range(0.1, 0.3), pitch, amp * rng.randf_range(0.1, 0.3), CHIME_PARTIALS, 4.0)
	return self

func clatter(at: float, seconds: float, amp: float = 0.3, hits: int = 7, hz: float = 800.0) -> DeepSynth:
	## Loose hard things tumbling: dice in a cup, stones down a slope.
	for i in range(hits):
		var when: float = at + seconds * (float(i) / float(maxi(1, hits))) + rng.randf() * seconds * 0.12
		clack(when, amp * rng.randf_range(0.45, 1.0), hz * rng.randf_range(0.6, 1.5))
	return self

func chord(at: float, seconds: float, root: float, steps: Array, amp: float = 0.3,
		partials: Array = CHIME_PARTIALS, spread: float = 0.0) -> DeepSynth:
	## Several notes of one voice, struck together or rolled. Steps are semitones off the root.
	for i in range(steps.size()):
		var hz: float = root * pow(2.0, float(steps[i]) / 12.0)
		bell(at + spread * float(i), seconds, hz, amp, partials, 2.2)
	return self

func sparkle(at: float, seconds: float, amp: float = 0.2, low: float = 1800.0, high: float = 5200.0,
		grains: int = 14) -> DeepSynth:
	## The glitter over a reveal: tiny high bells scattered through the tail.
	for i in range(grains):
		var when: float = at + rng.randf() * seconds
		bell(when, rng.randf_range(0.08, 0.22), rng.randf_range(low, high), amp * rng.randf_range(0.2, 0.6), CHIME_PARTIALS, 3.4)
	return self

# --- shaping -----------------------------------------------------------------------------------

func echoes(delay: float, feedback: float = 0.35, repeats: int = 3) -> DeepSynth:
	## The room a sound is in. A plain feedback delay is enough for rock, and the fights happen
	## underground: everything down there should answer itself.
	var step: int = int(delay * float(RATE))
	if step <= 0:
		return self
	var send: float = feedback
	for pass_index in range(repeats):
		var offset: int = step * (pass_index + 1)
		for i in range(samples.size() - offset):
			samples[i + offset] += samples[i] * send
		send *= feedback
	return self

func fade(seconds: float = 0.02) -> DeepSynth:
	## Never let a buffer end on a cliff; a cut waveform is a click.
	var count: int = mini(samples.size(), int(seconds * float(RATE)))
	for i in range(count):
		samples[samples.size() - 1 - i] *= float(i) / float(maxi(1, count))
	return self

func gain(scale: float) -> DeepSynth:
	for i in range(samples.size()):
		samples[i] *= scale
	return self

func normalise(to: float = 0.82) -> DeepSynth:
	## Every sound leaves the bank at the same headroom, so the mixer levels mean something.
	## The scaling itself happens in `stream`, in the pass that writes the samples out.
	_headroom = to
	return self

# --- baking ------------------------------------------------------------------------------------

func stream(loop: bool = false) -> AudioStreamWAV:
	## Levelled, soft-clipped and written out as 16-bit mono in one pass. The soft knee is what
	## keeps a stack of voices from tearing when they all land on the same sample.
	fade(0.008)
	var scale: float = 1.0
	if _headroom > 0.0:
		var loudest: float = peak()
		if loudest > 0.0001:
			scale = _headroom / loudest
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var value: float = samples[i] * scale
		if value > 0.7:
			value = 0.7 + 0.3 * tanh((value - 0.7) / 0.3)
		elif value < -0.7:
			value = -0.7 + 0.3 * tanh((value + 0.7) / 0.3)
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
