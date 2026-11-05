// The two banks side by side: every sound rendered by the JavaScript engine at the game's
// rate, and (if a folder of them is given) the same sound as the game's synth baked it, each
// measured for length, loudness and brightness. A recipe ported wrong shows up as a sound
// that is much louder, longer, shorter or brighter than its twin.
//
//   node tools/sound/parity.mjs <out dir> [<godot dump dir>]
//
// With only an out dir, writes the JavaScript bank there as WAV (one file a name) and a
// features.json beside them. With a Godot dump too (build/sound_dump.gd writes one), compares
// the two and prints every sound that disagrees, exiting 1 if any does.

import { mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { PICKS, GAME_RATE } from './picks.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
globalThis.DEEP_SOUND_RATE = GAME_RATE;
createRequire(import.meta.url)(path.join(here, 'synth.js'));
const D = globalThis.DeepSound3;
const RATE = D.RATE;

function wav(file, f32) {
	const n = f32.length, buf = Buffer.alloc(44 + n * 2);
	buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8); buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
	buf.writeUInt32LE(RATE, 24); buf.writeUInt32LE(RATE * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * 2, 40);
	for (let i = 0; i < n; i++) buf.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(f32[i] * 32767))), 44 + i * 2);
	writeFileSync(file, buf);
}
function readWav(file) {
	const buffer = readFileSync(file);
	let at = 12, rate = RATE, data = null;
	while (at + 8 <= buffer.length) {
		const id = buffer.toString('ascii', at, at + 4), size = buffer.readUInt32LE(at + 4);
		if (id === 'fmt ') rate = buffer.readUInt32LE(at + 12);
		else if (id === 'data') data = buffer.subarray(at + 8, at + 8 + size);
		at += 8 + size + (size & 1);
	}
	const out = new Float32Array(data.length >> 1);
	for (let i = 0; i < out.length; i++) out[i] = data.readInt16LE(i * 2) / 32768;
	return { rate, samples: out };
}
// Length to the last sample above 1% of the peak, loudness over the whole buffer, and the
// spectral centroid (a 2048-point FFT, averaged over the sound) as brightness.
export function features(b, rate) {
	let peak = 0, power = 0, last = 0;
	for (let i = 0; i < b.length; i++) { const a = Math.abs(b[i]); if (a > peak) peak = a; power += b[i] * b[i]; }
	for (let i = 0; i < b.length; i++) if (Math.abs(b[i]) > peak * 0.01) last = i;
	const N = 2048, spectrum = new Float64Array(N / 2);
	for (let off = 0; off + N <= b.length; off += N) {
		const re = new Float64Array(N), im = new Float64Array(N);
		for (let i = 0; i < N; i++) re[i] = b[off + i] * (0.5 - 0.5 * Math.cos(2 * Math.PI * i / N));
		fft(re, im);
		for (let k = 0; k < N / 2; k++) spectrum[k] += re[k] * re[k] + im[k] * im[k];
	}
	let num = 0, den = 0;
	for (let k = 1; k < N / 2; k++) { num += spectrum[k] * k * rate / N; den += spectrum[k]; }
	return { seconds: b.length / rate, tail: last / rate, peak, rms_db: 20 * Math.log10(Math.sqrt(power / Math.max(1, b.length)) + 1e-9), centroid: den > 0 ? num / den : 0 };
}
function fft(re, im) {
	const n = re.length;
	for (let i = 1, j = 0; i < n; i++) {
		let bit = n >> 1;
		for (; j & bit; bit >>= 1) j ^= bit;
		j ^= bit;
		if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; }
	}
	for (let len = 2; len <= n; len <<= 1) {
		const ang = -2 * Math.PI / len, wr = Math.cos(ang), wi = Math.sin(ang);
		for (let i = 0; i < n; i += len) {
			let cr = 1, ci = 0;
			for (let j = 0; j < len / 2; j++) {
				const a = i + j, b = a + len / 2;
				const tr = re[b] * cr - im[b] * ci, ti = re[b] * ci + im[b] * cr;
				re[b] = re[a] - tr; im[b] = im[a] - ti; re[a] += tr; im[a] += ti;
				const nr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = nr;
			}
		}
	}
}

const [outDir, godotDir] = process.argv.slice(2);
if (!outDir) { console.error('node tools/sound/parity.mjs <out dir> [<godot dump dir>]'); process.exit(2); }
mkdirSync(outDir, { recursive: true });
const js = {};
for (const name of D.NAMES) {
	const b = D.sfx(name, PICKS[name] ?? 0);
	wav(path.join(outDir, name + '.wav'), b);
	js[name] = features(b, RATE);
}
writeFileSync(path.join(outDir, 'features.json'), JSON.stringify(js, null, 1));
console.log(`JavaScript bank: ${D.NAMES.length} sounds at ${RATE} Hz written to ${outDir}`);
if (!godotDir) process.exit(0);
// Tolerances: a port is a port, not a copy; the random grains differ and the oscillators are
// not bit for bit. What is caught is a wrong argument: a sound twice as loud, half as long,
// an octave brighter.
let bad = 0;
console.log('name              rms js/gd   tail js/gd   centroid js/gd');
for (const name of D.NAMES) {
	const file = path.join(godotDir, name + '.wav');
	if (!existsSync(file)) { console.log(`${name.padEnd(16)} MISSING in the Godot dump`); bad++; continue; }
	const { rate, samples } = readWav(file);
	const g = features(samples, rate), j = js[name];
	const rmsDiff = Math.abs(g.rms_db - j.rms_db), tailRatio = (g.tail + 0.02) / (j.tail + 0.02), centRatio = (g.centroid + 50) / (j.centroid + 50);
	const wrong = rmsDiff > 3.0 || tailRatio > 1.6 || tailRatio < 1 / 1.6 || centRatio > 1.6 || centRatio < 1 / 1.6;
	if (wrong) bad++;
	if (wrong || process.argv.includes('--all')) console.log(`${name.padEnd(16)} ${j.rms_db.toFixed(1).padStart(6)}/${g.rms_db.toFixed(1).padStart(6)}   ${j.tail.toFixed(2)}/${g.tail.toFixed(2)}   ${Math.round(j.centroid).toString().padStart(5)}/${Math.round(g.centroid).toString().padStart(5)}${wrong ? '   <-- differs' : ''}`);
}
console.log(bad ? `${bad} sounds differ` : 'every sound agrees within tolerance');
process.exit(bad ? 1 : 0);
