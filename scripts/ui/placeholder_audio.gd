extends RefCounted
## Small, original synthesized placeholders; replace with authored sound assets later.
static func tone(frequency: float, duration: float, strength: float = 0.16) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(stream.mix_rate)
		var envelope := minf(1.0, float(i) / 80.0) * pow(1.0 - float(i) / float(samples), 2.0)
		var sample := sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 2.02 * t)
		bytes.encode_s16(i * 2, int(sample * strength * envelope * 32767))
	stream.data = bytes
	return stream
