extends RefCounted
## Small, original synthesized placeholders; replace with authored sound assets later.
const RATE := 22050

static func tone(frequency: float, duration: float, strength: float = 0.16) -> AudioStreamWAV:
	return sequence([[frequency, 0.0, duration, strength]], duration)

static func sequence(notes: Array, length: float) -> AudioStreamWAV:
	## Several notes mixed into one clip: each is [frequency, start, duration, strength].
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	var samples := int(length * RATE)
	var mix := PackedFloat32Array()
	mix.resize(samples)
	for note in notes:
		var frequency := float(note[0])
		var first := int(float(note[1]) * RATE)
		var span := int(float(note[2]) * RATE)
		var strength := float(note[3])
		for i in range(span):
			var index := first + i
			if index >= samples:
				break
			var t := float(i) / float(RATE)
			var envelope := minf(1.0, float(i) / 80.0) * pow(1.0 - float(i) / float(span), 2.0)
			mix[index] += (sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 2.02 * t)) * strength * envelope
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		bytes.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767))
	stream.data = bytes
	return stream

static func fanfare() -> AudioStreamWAV:
	## A rising major arpeggio that holds its top note.
	return sequence([[523.25, 0.0, 0.22, 0.14], [659.25, 0.11, 0.22, 0.14], [783.99, 0.22, 0.26, 0.14],
		[1046.5, 0.36, 0.7, 0.15], [783.99, 0.36, 0.7, 0.07], [523.25, 0.36, 0.7, 0.06]], 1.1)

static func dirge() -> AudioStreamWAV:
	## Falling minor steps, low and slow.
	return sequence([[329.63, 0.0, 0.42, 0.15], [311.13, 0.32, 0.42, 0.15], [246.94, 0.64, 0.9, 0.16],
		[164.81, 0.64, 0.9, 0.08]], 1.6)

static func sparkle() -> AudioStreamWAV:
	return sequence([[1567.98, 0.0, 0.16, 0.08], [2093.0, 0.06, 0.22, 0.07]], 0.3)

static func coins() -> AudioStreamWAV:
	return sequence([[1318.5, 0.0, 0.08, 0.07], [1760.0, 0.07, 0.08, 0.07], [1318.5, 0.14, 0.08, 0.06], [2093.0, 0.21, 0.14, 0.07]], 0.38)

static func thud() -> AudioStreamWAV:
	return sequence([[98.0, 0.0, 0.22, 0.26], [146.83, 0.0, 0.12, 0.1]], 0.24)

static func shatter() -> AudioStreamWAV:
	return sequence([[2349.3, 0.0, 0.06, 0.08], [1975.5, 0.03, 0.07, 0.08], [2793.8, 0.07, 0.05, 0.06], [1244.5, 0.1, 0.18, 0.06]], 0.3)

static func flourish() -> AudioStreamWAV:
	## For a rare find: a quick upward run into a bright chord.
	return sequence([[783.99, 0.0, 0.12, 0.1], [987.77, 0.07, 0.12, 0.1], [1174.7, 0.14, 0.14, 0.1],
		[1567.98, 0.22, 0.6, 0.11], [1174.7, 0.22, 0.6, 0.06], [1975.5, 0.3, 0.5, 0.05]], 0.9)
