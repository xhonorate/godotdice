class_name DeepKit
extends RefCounted
## The sound bank's kit: the handful of gestures every recipe is built from, each a few voices
## of the synth laid at a time. Felt under anything the hand does, a tok for a die, a ping for
## the interface, a crack and debris for a gem on stone, embers under the Furnace's gems, a
## chord on a warm pad for the big moments.
##
## Every helper takes the synth first and returns it, so a recipe in `sound_bank.gd` reads as
## the list of things you would hear. The same kit, in JavaScript, is what the review pages
## played (`tools/sound/`); a recipe here is its line-for-line port, and `tools/sound/parity`
## checks the two still agree.

const C5: float = 523.25
const C6: float = 1046.5

# --- the hand ----------------------------------------------------------------------------------

static func ping(s: DeepSynth, at: float, hz: float, q: float = 24.0, amp: float = 0.4, click: float = 0.03) -> DeepSynth:
	## The interface's voice: a ping with a sine body an octave under it.
	s.ping(at, hz, q, amp, click)
	s.tone(at, minf(0.5, q / (PI * hz) * 5.0), hz * 0.5, -1.0, amp * 0.18, "sine", 3.5, 0.003)
	return s

static func felt(s: DeepSynth, at: float, hz: float = 210.0, amp: float = 0.3) -> DeepSynth:
	## The soft thump under anything the hand does.
	s.thump(at, 0.08, hz, amp, 0.1)
	s.noise(at, 0.016, amp * 0.25, 2000.0, 600.0, 5.0, 0.0008)
	return s

static func tok(s: DeepSynth, at: float, amp: float = 0.35, hz: float = 620.0) -> DeepSynth:
	## A die, or any small hard thing set down.
	s.tone(at, 0.028, hz, hz * 0.66, amp, "triangle", 5.0, 0.001)
	s.noise(at, 0.018, amp * 0.5, 1100.0, 500.0, 5.0, 0.0005)
	return s

static func knock(s: DeepSynth, at: float, hz: float = 240.0, amp: float = 0.4, damping: float = 0.93, soft: float = 0.4) -> DeepSynth:
	## A damped pluck (wood or stone) over felt.
	s.pluck(at, 0.14, hz, amp, damping, soft)
	felt(s, at, hz * 0.6, amp * 0.5)
	return s

# --- ringing -----------------------------------------------------------------------------------

static func ladder(s: DeepSynth, at: float, root: float, steps: Array, gap: float, q: float = 90.0, amp: float = 0.36) -> DeepSynth:
	## Pings up (or down) a chord, one every `gap` seconds.
	for i in range(steps.size()):
		ping(s, at + float(i) * gap, root * pow(2.0, float(steps[i]) / 12.0), q, amp, 0.05)
	return s

static func sparkle(s: DeepSynth, at: float, seconds: float, amp: float = 0.12, grains: int = 8, low: float = 1800.0, high: float = 5200.0) -> DeepSynth:
	## Glitter: tiny high pings scattered through the tail.
	for _i in range(grains):
		s.ping(at + s.rng.randf() * seconds, s.rng.randf_range(low, high), s.rng.randf_range(18.0, 50.0), amp * s.rng.randf_range(0.4, 1.0), 0.02)
	return s

static func chime(s: DeepSynth, at: float, hz: float, amp: float = 0.3, seconds: float = 0.8) -> DeepSynth:
	## A warm chime: a ring, its octave, a sine body.
	s.ping(at, hz, 70.0, amp, 0.0)
	s.ping(at, hz * 2.0, 40.0, amp * 0.18, 0.0)
	s.tone(at, minf(seconds, 0.4), hz * 0.5, -1.0, amp * 0.15, "sine", 3.0, 0.004)
	return s

static func metal(s: DeepSynth, at: float, hz: float, seconds: float, amp: float) -> DeepSynth:
	## Struck metal: an inharmonic FM clang.
	s.fm(at, seconds, hz, {"ratio": 1.41, "index": 3.2, "decay": 3.5, "amp": amp, "curve": 3.0, "attack": 0.001})
	return s

static func coin(s: DeepSynth, at: float, amp: float = 0.16) -> DeepSynth:
	metal(s, at, s.rng.randf_range(1800.0, 3400.0), s.rng.randf_range(0.12, 0.26), amp)
	tok(s, at, amp * 0.3, 1600.0)
	return s

# --- the analog voices -------------------------------------------------------------------------

static func sqk(s: DeepSynth, at: float, hz: float, seconds: float, amp: float, o: Dictionary = {}) -> DeepSynth:
	## A squelch: a saw through a resonant filter that snaps shut.
	var opts: Dictionary = {"amp": amp, "shape": "saw", "cutoff": 200.0, "env": 2200.0, "res": 0.5, "decay": 0.16, "sustain": 0.1, "release": 0.08, "sub": 0.35, "drive": 0.25}
	opts.merge(o, true)
	s.analog(at, seconds, hz, opts)
	return s

static func stab(s: DeepSynth, at: float, root: float, steps: Array, amp: float = 0.26, seconds: float = 0.3, o: Dictionary = {}) -> DeepSynth:
	## A chord stabbed on a saw.
	for k in steps:
		var opts: Dictionary = {"amp": amp, "shape": "saw", "unison": 2, "detune": 8.0, "cutoff": 400.0, "env": 2800.0, "res": 0.3, "attack": 0.008, "decay": 0.3, "sustain": 0.2, "release": 0.2}
		opts.merge(o, true)
		s.analog(at, seconds, root * pow(2.0, float(k) / 12.0), opts)
	return s

static func swell(s: DeepSynth, at: float, root: float, steps: Array, amp: float = 0.24, seconds: float = 0.7) -> DeepSynth:
	## A chord swelling on a saw pad: brassy. The Hollow's rite keeps it; the rest of the big
	## moments moved to `swell_warm`.
	for k in steps:
		s.analog(at, seconds, root * pow(2.0, float(k) / 12.0), {"amp": amp, "shape": "saw", "unison": 3, "detune": 9.0, "cutoff": 220.0, "env": 2200.0, "res": 0.25, "attack": 0.25, "decay": 0.9, "sustain": 0.15, "release": 0.5})
	return s

static func swell_warm(s: DeepSynth, at: float, root: float, steps: Array, amp: float = 0.24, seconds: float = 0.7) -> DeepSynth:
	## The same chord on a triangle pad with a sine root under it, lowpassed: warm, not brassy.
	for k in steps:
		var hz: float = root * pow(2.0, float(k) / 12.0)
		s.voice(at, seconds, hz, amp * 0.9, "triangle", minf(0.3, seconds * 0.35), seconds * 0.7, 2, 6.0, 2200.0, 0.0, 0.004, 0.0)
		s.tone(at, seconds * 1.2, hz * 0.5, -1.0, amp * 0.25, "sine", 1.5, seconds * 0.3)
	return s

static func riser(s: DeepSynth, at: float, seconds: float, amp: float = 0.3, hz: float = 110.0) -> DeepSynth:
	## A rise into a big moment: a saw opening up under air sweeping up.
	s.voice(at, seconds, hz, amp, "saw", seconds * 0.4, 0.25, 2, 8.0, 180.0, 18.0)
	s.noise(at, seconds, amp * 0.5, 300.0, 5000.0, 0.8, seconds * 0.85, 200.0)
	return s

# --- air, stone and weight ----------------------------------------------------------------------

static func crackle(s: DeepSynth, at: float, seconds: float, grains: int, amp: float = 0.1) -> DeepSynth:
	## Fire: tiny bright bursts scattered through the tail.
	for _i in range(grains):
		s.noise(at + s.rng.randf() * seconds, 0.012, amp * s.rng.randf_range(0.4, 1.2), 7000.0, 3000.0, 5.0, 0.0005, 1500.0)
	return s

static func embers(s: DeepSynth, at: float, seconds: float, grains: int, amp: float) -> DeepSynth:
	## Crackle lowpassed hard: the warmth under Red, the fire at a landing.
	var y := DeepSynth.new(seconds + 0.05, 4100 + grains)
	crackle(y, 0.0, seconds, grains, amp)
	y.lowpass(2000.0, 3)
	lay(s, y.samples, at)
	return s

static func bubbles(s: DeepSynth, at: float, seconds: float, count: int, low: float = 140.0, high: float = 320.0, amp: float = 0.16) -> DeepSynth:
	## Something thick coming to the boil.
	for _i in range(count):
		var f: float = s.rng.randf_range(low, high)
		s.tone(at + s.rng.randf() * seconds, 0.1, f, f * 1.9, amp * s.rng.randf_range(0.6, 1.2), "sine", 3.5, 0.004)
	return s

static func breath(s: DeepSynth, at: float, seconds: float, amp: float, f0: float, f1: float, attack: float = 0.3) -> DeepSynth:
	## Air with a soft front.
	s.noise(at, seconds, amp, f0, f1, 1.6, seconds * attack, minf(f0, f1) * 0.5)
	return s

static func crack(s: DeepSynth, at: float, amp: float = 0.4, hz: float = 1800.0, seconds: float = 0.03) -> DeepSynth:
	## A stone cracking: a short bright burst and two low-Q inharmonic rings.
	s.noise(at, seconds, amp, 7000.0, 1200.0, 4.5, 0.0005, 600.0)
	s.ping(at, hz, 9.0, amp * 0.5, 0.0)
	s.ping(at, hz * 1.37, 7.0, amp * 0.3, 0.0)
	return s

static func crunch(s: DeepSynth, at: float, seconds: float, grains: int = 7, amp: float = 0.2, hi: float = 3500.0, lo: float = 700.0) -> DeepSynth:
	## Debris: small grains falling in band and loudness.
	for i in range(grains):
		var t: float = float(i) / float(grains)
		s.noise(at + t * seconds + s.rng.randf() * seconds * 0.08, 0.02 + s.rng.randf() * 0.02, amp * (1.0 - t * 0.6) * s.rng.randf_range(0.5, 1.0), hi * (1.0 - t * 0.6), lo, 4.5, 0.0008, 300.0)
	return s

static func dust(s: DeepSynth, at: float, seconds: float, grains: int, amp: float, hi: float = 1600.0, lo: float = 400.0) -> DeepSynth:
	## Softer debris: the altar's smoke, the dust of a landing.
	for i in range(grains):
		var t: float = float(i) / float(grains)
		s.noise(at + t * seconds + s.rng.randf() * seconds * 0.1, 0.02 + s.rng.randf() * 0.02, amp * (1.0 - t * 0.5) * s.rng.randf_range(0.5, 1.0), hi * (1.0 - t * 0.5), lo, 4.0, 0.001, 200.0)
	return s

static func fizz(s: DeepSynth, at: float, seconds: float, grains: int, amp: float, hi0: float = 5500.0, lo0: float = 3000.0, fall: float = 0.5) -> DeepSynth:
	## A cloud of tiny grains whose band falls as it dies: soda in a glass.
	for _i in range(grains):
		var t: float = s.rng.randf()
		var k: float = 1.0 - t * fall
		s.noise(at + t * seconds, 0.006 + s.rng.randf() * 0.008, amp * (1.0 - t * 0.7) * s.rng.randf_range(0.4, 1.0), hi0 * k, lo0 * k, 5.0, 0.0004, lo0 * k * 0.4)
	return s

static func boom(s: DeepSynth, at: float, amp: float = 0.5, hz: float = 110.0, seconds: float = 0.35) -> DeepSynth:
	## The low weight of a blow.
	s.tone(at, seconds, hz, 38.0, amp, "sine", 3.0, 0.001)
	return s

static func rattle(s: DeepSynth, at: float, seconds: float, count: int, amp: float, hz0: float = 700.0, accel: float = 1.0) -> DeepSynth:
	## Toks that quicken or slow.
	var t: float = at
	var gap: float = seconds / float(maxi(1, count))
	for _i in range(count):
		tok(s, t, amp * s.rng.randf_range(0.6, 1.0), hz0 * s.rng.randf_range(0.85, 1.15))
		t += gap
		gap *= accel
	return s

static func growl(s: DeepSynth, at: float, seconds: float, amp: float, hz: float = 24.0, seed_value: int = 900) -> DeepSynth:
	## Low noise and a wobbling sub, chopped by a slow tremolo: something big drawing breath.
	var y := DeepSynth.new(seconds, seed_value)
	y.noise(0.0, seconds, amp, 900.0, 250.0, 1.4, seconds * 0.3, 120.0)
	y.tone(0.0, seconds, 58.0, 52.0, amp * 0.8, "sine", 1.5, seconds * 0.3, 0.02, 5.0)
	y.tremolo(hz, 0.85)
	lay(s, y.samples, at)
	return s

static func stone(s: DeepSynth, at: float, size: float = 1.0, hz: float = 330.0) -> DeepSynth:
	## A gem on stone: a crack, debris, weight. Sized like the old drum impact, so a recipe
	## built on that keeps its proportions.
	crack(s, at, 0.42 * minf(1.2, size), hz * 2.6, 0.03 * size)
	crunch(s, at + 0.02, 0.18 * size, int(round(4.0 + 3.0 * size)), 0.18 * size, 3000.0, 600.0)
	s.thump(at, 0.25 * size, 120.0 / sqrt(size), 0.5 * size, 0.3)
	return s

static func impact(s: DeepSynth, at: float, size: float = 1.0, hz: float = 330.0) -> DeepSynth:
	## The drum impact: a thwack, a crack, weight. Kept for the slam and the plain strike.
	s.tone(at, 0.07 * size, hz, hz * 0.28, 0.5, "triangle", 4.5, 0.001)
	s.noise(at, 0.05 * size, 0.45, 8000.0, 700.0, 4.5, 0.0008, 500.0)
	s.tone(at, 0.32 * size, 150.0, 42.0, 0.6 * minf(1.3, size), "sine", 3.2, 0.001)
	if size >= 1.0:
		s.noise(at + 0.01, 0.18 * size, 0.22, 2600.0, 300.0, 3.0, 0.002)
	return s

# --- drums laid in whole ------------------------------------------------------------------------

static func kick(o: Dictionary = {}) -> PackedFloat32Array:
	var opts: Dictionary = {"hz": 160.0, "to": 46.0, "dur": 0.42, "click": 0.12, "lp": 3200.0}
	opts.merge(o, true)
	var seconds: float = float(opts.dur)
	var y := DeepSynth.new(seconds, int(opts.get("seed", 0)))
	y.tone(0.0, seconds, float(opts.hz), float(opts.to), 0.9, "sine", 3.2, 0.001)
	if float(opts.click) > 0.0:
		y.noise(0.0, 0.012, float(opts.click), 6000.0, 1500.0, 5.0, 0.0005)
	if float(opts.lp) > 0.0:
		y.lowpass(float(opts.lp))
	return y.samples

static func thud() -> PackedFloat32Array:
	var y := DeepSynth.new(0.9)
	y.tone(0.0, 0.85, 62.0, 38.0, 0.8, "sine", 2.4, 0.003)
	y.noise(0.0, 0.3, 0.12, 400.0, 120.0, 2.5)
	return y.samples

static func lay(s: DeepSynth, other: PackedFloat32Array, at: float, scale: float = 1.0) -> DeepSynth:
	## A finished sound laid into this one at `at` seconds, cut at the end rather than wrapped
	## round (`DeepSynth.add` wraps, which is for loops).
	var start: int = maxi(0, int(round(at * float(DeepSynth.RATE))))
	var count: int = mini(other.size(), s.samples.size() - start)
	for i in range(count):
		s.samples[start + i] += other[i] * scale
	return s

# --- out ---------------------------------------------------------------------------------------

static func fin(s: DeepSynth, peak: float) -> AudioStreamWAV:
	## Every sound leaves the bank the same way: lowpassed just under the ceiling, through a
	## little tape, levelled to its own peak.
	s.lowpass(9500.0)
	s.saturate(1.12)
	return s.normalise(peak).stream()
