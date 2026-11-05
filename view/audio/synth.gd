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
## frequency glide is an increment, and nothing calls a function per sample. The bank is 70
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
## A tapped wine glass: inharmonic and dark.
const GLASS_PARTIALS: Array = [1.0, 2.32, 4.25, 6.63]
## A music-box comb tooth.
const TINE_PARTIALS: Array = [1.0, 3.95, 9.2]

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

func voice(at: float, seconds: float, hz: float, amp: float = 0.3, shape: String = "saw",
		attack: float = 0.05, release: float = 0.4, unison: int = 1, detune: float = 0.0,
		cutoff: float = 0.0, bloom: float = 0.0, vibrato: float = 0.0, tremolo: float = 0.0) -> DeepSynth:
	## A held note, where `tone` is a struck one: it rises over `attack`, holds for `seconds`
	## and dies over `release` after them. `unison` copies spread `detune` cents apart are what
	## make a pad wide; `cutoff` darkens it through two gentle low passes, and `bloom` opens
	## that filter as the note swells, which is what makes a horn speak. `vibrato` bends the
	## pitch (a fraction) once the note has settled; `tremolo` shakes its loudness, which is a
	## bowed string played in a hurry.
	var start: int = maxi(0, int(at * float(RATE)))
	var hold: int = int(seconds * float(RATE))
	var count: int = hold + int(release * float(RATE))
	var limit: int = mini(count, samples.size() - start)
	if hold <= 0 or limit <= 0:
		return self
	var wave: int = int(SHAPES.get(shape, SAW))
	var copies: int = clampi(unison, 1, 4)
	var phases := PackedFloat64Array()
	var incs := PackedFloat64Array()
	for u in range(copies):
		var spread: float = 0.0 if copies == 1 else (float(u) / float(copies - 1) - 0.5) * 2.0
		incs.append(hz * pow(2.0, spread * detune / 1200.0) / float(RATE))
		phases.append(rng.randf())
	var rise: int = clampi(int(attack * float(RATE)), 1, hold)
	var fall: int = maxi(1, count - hold)
	var tail: float = exp(-5.0)
	var span: float = 1.0 / (1.0 - tail)
	var decay_step: float = exp(-5.0 / float(fall))
	var decay: float = 1.0
	var vibrato_inc: float = TAU * 5.2 / float(RATE)
	var vibrato_phase: float = 0.0
	var tremolo_inc: float = TAU * 6.5 / float(RATE)
	var tremolo_phase: float = 0.0
	var closed: float = clampf(TAU * cutoff / float(RATE), 0.0, 1.0)
	var filtered: bool = cutoff > 0.0
	var low_a: float = 0.0
	var low_b: float = 0.0
	var each: float = amp / sqrt(float(copies))
	for i in range(limit):
		var envelope: float
		if i < rise:
			envelope = float(i) / float(rise)
		elif i < hold:
			envelope = 1.0
		else:
			decay *= decay_step
			envelope = (decay - tail) * span
		var bend: float = 1.0
		if vibrato > 0.0 and i > rise:
			vibrato_phase += vibrato_inc
			bend += vibrato * sin(vibrato_phase) * minf(1.0, float(i - rise) / 6000.0)
		var value: float = 0.0
		for u in range(copies):
			var p: float = phases[u] + incs[u] * bend
			p -= floorf(p)
			phases[u] = p
			if wave == SINE:
				value += sin(TAU * p)
			elif wave == TRIANGLE:
				value += 4.0 * absf(p - 0.5) - 1.0
			elif wave == SAW:
				value += 2.0 * p - 1.0
			else:
				value += 1.0 if p < 0.5 else -1.0
		if filtered:
			var a: float = minf(1.0, closed * (1.0 + bloom * envelope))
			low_a += (value - low_a) * a
			low_b += (low_a - low_b) * a
			value = low_b
		if tremolo > 0.0:
			tremolo_phase += tremolo_inc
			value *= 1.0 - tremolo * (0.5 + 0.5 * sin(tremolo_phase))
		samples[start + i] += value * each * envelope
	return self

func pluck(at: float, seconds: float, hz: float, amp: float = 0.4, damping: float = 0.996, soft: float = 0.0) -> DeepSynth:
	## A string or a crystal shard: noise trapped in a ring one wavelength long, averaged a
	## little smoother on every pass. Karplus and Strong, 1983, and still the cheapest
	## convincing struck string there is. `soft` smooths the noise before it is trapped: a
	## thumb rather than a pick, which is what a tune wants.
	var start: int = maxi(0, int(at * float(RATE)))
	var count: int = int(seconds * float(RATE))
	var limit: int = mini(count, samples.size() - start)
	## The ring is a whole number of samples long, and the averaging (each sample with the one
	## after it) takes half a sample off it, which alone plays every note up to a third of a
	## semitone sharp: sour against the pads. An all-pass makes up the fraction, so the loop
	## is exactly one period.
	var period: float = float(RATE) / maxf(hz, 20.0)
	var ring_size: int = maxi(2, int(floor(period + 0.5)))
	var fraction: float = period + 0.5 - float(ring_size)
	if fraction < 0.1 and ring_size > 2:
		ring_size -= 1
		fraction += 1.0
	var tune: float = (1.0 - fraction) / (1.0 + fraction)
	if count <= 0 or limit <= 0:
		return self
	var ring: PackedFloat32Array = PackedFloat32Array()
	ring.resize(ring_size)
	for i in range(ring_size):
		ring[i] = rng.randf() * 2.0 - 1.0
	if soft > 0.0:
		var keep: float = clampf(soft, 0.0, 0.95)
		var last: float = 0.0
		for _pass in range(2):
			for i in range(ring_size):
				last = last * keep + ring[i] * (1.0 - keep)
				ring[i] = last
		var loudest: float = 0.0
		for value in ring:
			loudest = maxf(loudest, absf(value))
		if loudest > 0.0001:
			for i in range(ring_size):
				ring[i] /= loudest
	var cursor: int = 0
	var decay_step: float = exp(-3.6 / float(limit))
	var decay: float = 1.0
	var pass_in: float = 0.0
	var pass_out: float = 0.0
	for i in range(limit):
		var value: float = ring[cursor]
		var next: int = (cursor + 1) % ring_size
		var averaged: float = (value + ring[next]) * 0.5 * damping
		pass_out = tune * averaged + pass_in - tune * pass_out
		pass_in = averaged
		ring[cursor] = pass_out
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

func ping(at: float, hz: float, q: float = 40.0, amp: float = 0.3, click: float = 0.08) -> DeepSynth:
	## A resonant filter struck once: exactly a damped sine, with the tick of the impulse in
	## front of it. `q` is how long it rings, in cycles. The analog "pew", and the voice most
	## of the interface speaks in.
	var tau: float = q / (PI * hz)
	var start: int = maxi(0, int(round(at * float(RATE))))
	var limit: int = mini(int(round(minf(2.5, tau * 7.0) * float(RATE))), samples.size() - start)
	if limit <= 0:
		return self
	var k: float = 1.0 / (tau * float(RATE))
	var inc: float = TAU * hz / float(RATE)
	var phase: float = 0.0
	for i in range(limit):
		phase += inc
		samples[start + i] += amp * exp(-float(i) * k) * sin(phase) * minf(1.0, float(i) / 40.0)
	if click > 0.0:
		noise(at, 0.004, amp * click, 9000.0, 4000.0, 5.0, 0.0003)
	return self

func fm(at: float, seconds: float, hz: float, o: Dictionary = {}) -> DeepSynth:
	## Two-operator FM: a sine carrier pushed by a sine modulator `ratio` times its pitch, as
	## far as `index`, which falls away at `decay` (the tine of a Rhodes dies before its body)
	## or rises over `index_attack` (brass). `fb` feeds the carrier back on itself for a
	## sawtooth edge; `bend` glides in from that many semitones away. A second modulator
	## (`ratio2`, `index2`, `decay2`) adds a clang. Struck metal, coins, a brass flare.
	var start: int = maxi(0, int(round(at * float(RATE))))
	var count: int = int(round(seconds * float(RATE)))
	var limit: int = mini(count, samples.size() - start)
	if count <= 0 or limit <= 0:
		return self
	var ratio: float = float(o.get("ratio", 2.0))
	var index: float = float(o.get("index", 3.0))
	var amp: float = float(o.get("amp", 0.4))
	var ratio2: float = float(o.get("ratio2", 0.0))
	var index2: float = float(o.get("index2", 0.0))
	var fb: float = float(o.get("fb", 0.0))
	var bend: float = float(o.get("bend", 0.0))
	var env: PackedFloat32Array = _struck(count, float(o.get("attack", 0.004)), float(o.get("curve", 3.0)))
	var ienv: PackedFloat32Array = _struck(count, maxf(0.001, float(o.get("index_attack", 0.0))), float(o.get("decay", 4.0)))
	var ienv2: PackedFloat32Array = _struck(count, 0.001, float(o.get("decay2", 6.0))) if index2 > 0.0 else PackedFloat32Array()
	var ph: float = 0.0
	var phm: float = 0.0
	var phm2: float = 0.0
	var last: float = 0.0
	var glide: int = mini(count, int(round(0.08 * float(RATE))))
	for i in range(limit):
		var f: float = hz
		if bend != 0.0 and i < glide:
			f = hz * pow(2.0, bend * (1.0 - float(i) / float(glide)) / 12.0)
		var inc: float = f / float(RATE)
		phm += inc * ratio
		if phm >= 1.0:
			phm -= 1.0
		var modulation: float = sin(TAU * phm) * index * ienv[i]
		if index2 > 0.0:
			phm2 += inc * ratio2
			if phm2 >= 1.0:
				phm2 -= 1.0
			modulation += sin(TAU * phm2) * index2 * ienv2[i]
		ph += inc
		if ph >= 1.0:
			ph -= 1.0
		var value: float = sin(TAU * ph + modulation + fb * last)
		last = value
		samples[start + i] += value * amp * env[i]
	return self

func analog(at: float, seconds: float, hz: float, o: Dictionary = {}) -> DeepSynth:
	## The classic subtractive voice: a saw, square or pulse (`unison` copies, `detune` cents
	## apart) into a resonant two-pole filter whose `cutoff` rides an envelope of its own
	## (`env` hertz up, falling over `decay` to `sustain` of it). The note holds for `seconds`
	## and lets go over `release`. `glide` slides in from that ratio of the pitch, `sub` adds a
	## sine an octave down, `drive` warms the filter's output and `lfo` wobbles the cutoff at
	## `lfo_hz`. The motor under the loupe, the drone under a battle.
	var amp: float = float(o.get("amp", 0.3))
	var shape_name: String = str(o.get("shape", "saw"))
	var wave: int = 4 if shape_name == "pulse" else int(SHAPES.get(shape_name, SAW))
	var copies: int = clampi(int(o.get("unison", 1)), 1, 5)
	var detune: float = float(o.get("detune", 0.0))
	var cutoff: float = float(o.get("cutoff", 800.0))
	var env_amount: float = float(o.get("env", 2000.0))
	var res: float = clampf(float(o.get("res", 0.3)), 0.0, 0.95)
	var attack: float = float(o.get("attack", 0.005))
	var f_decay: float = float(o.get("decay", 0.2))
	var sustain: float = float(o.get("sustain", 0.2))
	var release: float = float(o.get("release", 0.1))
	var sub: float = float(o.get("sub", 0.0))
	var pw: float = float(o.get("pw", 0.5))
	var glide: float = float(o.get("glide", 1.0))
	var drive: float = float(o.get("drive", 0.0))
	var lfo: float = float(o.get("lfo", 0.0))
	var lfo_inc: float = TAU * float(o.get("lfo_hz", 0.3)) / float(RATE)
	var start: int = maxi(0, int(round(at * float(RATE))))
	var hold: int = int(round(seconds * float(RATE)))
	var count: int = hold + int(round(release * float(RATE)))
	var limit: int = mini(count, samples.size() - start)
	if hold <= 0 or limit <= 0:
		return self
	var phases := PackedFloat64Array()
	var offs := PackedFloat64Array()
	for u in range(copies):
		var spread: float = 0.0 if copies == 1 else (float(u) / float(copies - 1) - 0.5) * 2.0
		offs.append(pow(2.0, spread * detune / 1200.0))
		phases.append(rng.randf())
	var sub_phase: float = 0.0
	var rise: int = clampi(int(round(attack * float(RATE))), 1, hold)
	var fall: int = maxi(1, count - hold)
	var tail: float = exp(-5.0)
	var span: float = 1.0 / (1.0 - tail)
	var decay_step: float = exp(-5.0 / float(fall))
	var decay: float = 1.0
	var f_step: float = exp(-4.0 / float(maxi(1, int(round(f_decay * float(RATE))))))
	var f_env: float = 1.0
	var glide_n: int = int(round(0.07 * float(RATE)))
	var ic1: float = 0.0
	var ic2: float = 0.0
	var k: float = 2.0 - 2.0 * res
	var each: float = amp / sqrt(float(copies))
	for i in range(limit):
		var envelope: float
		if i < rise:
			envelope = float(i) / float(rise)
		elif i < hold:
			envelope = 1.0
		else:
			decay *= decay_step
			envelope = (decay - tail) * span
		var f: float = hz
		if glide != 1.0 and i < glide_n:
			f = hz * pow(glide, 1.0 - float(i) / float(glide_n))
		var inc: float = f / float(RATE)
		var value: float = 0.0
		for u in range(copies):
			var p: float = phases[u] + inc * offs[u]
			p -= floorf(p)
			phases[u] = p
			value += _osc_at(wave, p, inc * offs[u], pw)
		if sub > 0.0:
			sub_phase += inc * 0.5
			if sub_phase >= 1.0:
				sub_phase -= 1.0
			value += sin(TAU * sub_phase) * sub * sqrt(float(copies))
		f_env *= f_step
		var fc: float = cutoff + env_amount * (sustain + (1.0 - sustain) * f_env)
		if lfo > 0.0:
			fc *= 1.0 + lfo * sin(lfo_inc * float(i))
		fc = clampf(fc, 20.0, CEILING)
		var g: float = tan(PI * fc / float(RATE))
		var a1: float = 1.0 / (1.0 + g * (g + k))
		var a2: float = g * a1
		var a3: float = g * a2
		var v3: float = value - ic2
		var v1: float = a1 * ic1 + a2 * v3
		var v2: float = ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		var out: float = v2
		if drive > 0.0:
			out = tanh(out * (1.0 + drive)) / tanh(1.0 + drive)
		samples[start + i] += out * each * envelope
	return self

static func _struck(count: int, attack: float, curve: float) -> PackedFloat32Array:
	## The struck envelope as a table: linear in, exponential out, landing on silence.
	var env := PackedFloat32Array()
	env.resize(maxi(0, count))
	var rise: int = clampi(int(round(attack * float(RATE))), 1, maxi(1, count - 1))
	var fall: float = curve * 2.6
	var tail: float = exp(-fall)
	var span: float = 1.0 / maxf(0.0001, 1.0 - tail)
	var step: float = exp(-fall / float(maxi(1, count - rise)))
	var decay: float = 1.0 / step
	for i in range(count):
		if i < rise:
			env[i] = float(i) / float(rise)
		else:
			decay *= step
			env[i] = (decay - tail) * span
	return env

static func _polyblep(t: float, dt: float) -> float:
	## The correction that keeps a saw's or a square's step from whistling: a band-limited
	## edge instead of a cliff.
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0

static func _osc_at(wave: int, t: float, dt: float, pw: float) -> float:
	## One sample of a band-limited oscillator at phase `t` (0 to 1), advancing `dt` a sample.
	if wave == SINE:
		return sin(TAU * t)
	if wave == TRIANGLE:
		return 4.0 * absf(t - 0.5) - 1.0
	if wave == SAW:
		return 2.0 * t - 1.0 - _polyblep(t, dt)
	if wave == SQUARE:
		var square: float = 1.0 if t < 0.5 else -1.0
		square += _polyblep(t, dt)
		square -= _polyblep(fmod(t + 0.5, 1.0), dt)
		return square
	var width: float = pw if pw > 0.0 else 0.25
	var pulse: float = 1.0 if t < width else -1.0
	pulse += _polyblep(t, dt)
	pulse -= _polyblep(fmod(t + 1.0 - width, 1.0), dt)
	return pulse

# --- shaping -----------------------------------------------------------------------------------

func lowpass(hz: float, passes: int = 1) -> DeepSynth:
	## One pole of low pass over the whole buffer (6 dB an octave), `passes` times over: what
	## takes the edge off a stone or a hiss before it leaves the bank.
	var a: float = clampf(TAU * hz / float(RATE), 0.001, 1.0)
	for _pass in range(passes):
		var low: float = 0.0
		for i in range(samples.size()):
			low += (samples[i] - low) * a
			samples[i] = low
	return self

func highpass(hz: float) -> DeepSynth:
	var a: float = clampf(TAU * hz / float(RATE), 0.001, 1.0)
	var low: float = 0.0
	for i in range(samples.size()):
		low += (samples[i] - low) * a
		samples[i] -= low
	return self

func saturate(drive: float = 1.5) -> DeepSynth:
	## Tape: the loud parts rounded off, the whole brought back to the same peak.
	var norm: float = tanh(drive)
	for i in range(samples.size()):
		samples[i] = tanh(samples[i] * drive) / norm
	return self

func tremolo(hz: float, depth: float) -> DeepSynth:
	## The whole buffer chopped by a slow sine: a motor, a growl, a shiver.
	var inc: float = TAU * hz / float(RATE)
	for i in range(samples.size()):
		samples[i] *= 1.0 - depth * (0.5 + 0.5 * sin(inc * float(i)))
	return self

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

func add(other: PackedFloat32Array, at_sample: int, scale: float = 1.0) -> DeepSynth:
	## Lays a finished sound into this one, wrapping round past the end: in a loop, the last
	## bar rings on into the first, so the seam is never heard. A sound longer than the whole
	## buffer is cut at one turn.
	var size: int = samples.size()
	if size == 0 or other.is_empty() or scale == 0.0:
		return self
	var start: int = posmod(at_sample, size)
	var first: int = mini(other.size(), size - start)
	for i in range(first):
		samples[start + i] += other[i] * scale
	var rest: int = mini(other.size() - first, start)
	for i in range(rest):
		samples[i] += other[first + i] * scale
	return self

func echo_round(delay_samples: int, feedback: float = 0.3, repeats: int = 2) -> DeepSynth:
	## `echoes` for a loop: what would fall off the end comes back in at the start.
	var size: int = samples.size()
	if delay_samples <= 0 or size == 0:
		return self
	var dry: PackedFloat32Array = samples.duplicate()
	var send: float = feedback
	for r in range(repeats):
		add(dry, delay_samples * (r + 1), send)
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
	return _written(scale, loop)

func loop_stream(scale: float = 1.0) -> AudioStreamWAV:
	## A buffer whose end runs straight on into its start (music, the air of a cave): no fade
	## at the end, which in a loop would be a dip, and a level set by the caller so the strips
	## of one piece keep their balance with each other.
	return _written(scale, true)

func _written(scale: float, loop: bool) -> AudioStreamWAV:
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
