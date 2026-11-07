// Bakes the score: the eight pieces in `picks.mjs`, written by the engine in `synth.js` at
// the game's rate, one Ogg loop a strip in audio/music/<id>/ (bed, deep, fight, warden), with
// a render.json beside them the way `tools/data-browser/music.mjs` writes one, so a strip
// replaced by hand (a DAW master) is still told apart.
//
//   node tools/sound/bake_music.mjs [id ...] [--wav <dir>]
//
// With no ids, bakes every piece. --wav also writes the raw strips as WAV to <dir>/<id>/.

import { mkdirSync, writeFileSync, rmSync, existsSync, readdirSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { PICKS, MUSIC_RATE, PIECES, SPEC_OF } from './picks.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '../..');
const LIVE_DIR = path.join(ROOT, 'audio/music');
const STRIPS = ['bed', 'deep', 'fight', 'warden'];
// Vorbis quality, -1 to 10: 6 is transparent for these mono loops.
const OGG_QUALITY = 6;

globalThis.DEEP_SOUND_RATE = MUSIC_RATE;
const require = createRequire(import.meta.url);
require(path.join(here, 'synth.js'));
const { createOggEncoder } = await import(pathToFileURL(path.join(ROOT, 'tools/data-browser/node_modules/wasm-media-encoders/dist/es/index.mjs')).href);
const D = globalThis.DeepSound3;
const RATE = D.RATE;

function wav(file, f32) {
	const n = f32.length, buf = Buffer.alloc(44 + n * 2);
	buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8); buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
	buf.writeUInt32LE(RATE, 24); buf.writeUInt32LE(RATE * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * 2, 40);
	for (let i = 0; i < n; i++) buf.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(f32[i] * 32767))), 44 + i * 2);
	writeFileSync(file, buf);
}
let encoder = null;
async function ogg(f32) {
	encoder ||= await createOggEncoder();
	// A fixed stream serial: the same render encodes to the same bytes, so git sees no change.
	encoder.configure({ channels: 1, sampleRate: RATE, vbrQuality: OGG_QUALITY, oggSerialNo: 0x44454550 });
	const parts = [];
	for (let i = 0; i < f32.length; i += 16384) parts.push(Buffer.from(encoder.encode([f32.subarray(i, i + 16384)])));
	parts.push(Buffer.from(encoder.finalize()));
	return Buffer.concat(parts);
}
const sha1 = (buffer) => createHash('sha1').update(buffer).digest('hex');

const args = process.argv.slice(2);
const wavAt = args.includes('--wav') ? args[args.indexOf('--wav') + 1] : null;
const ids = args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--wav');
// The score names each piece's spec in `from`; picks.mjs is the fallback for a track without one.
const score = JSON.parse(readFileSync(path.join(ROOT, 'content/score.json'), 'utf8'));
const inScore = Object.values(score.places || {}).flatMap((p) => p.tracks || []);
const wanted = ids.length ? ids : (inScore.length ? inScore : Object.values(PIECES));
let failed = 0;
for (const id of wanted) {
	const specId = score.tracks?.[id]?.from || SPEC_OF[id];
	if (!specId) { console.error(`No piece called ${id}; the score has ${Object.values(PIECES).join(', ')}`); failed++; continue; }
	const began = Date.now();
	const spec = D.spec(specId);
	const m = D.music(specId);
	const live = path.join(LIVE_DIR, id);
	mkdirSync(live, { recursive: true });
	const files = {};
	for (const strip of STRIPS) {
		const bytes = await ogg(m[strip]);
		writeFileSync(path.join(live, `${strip}.ogg`), bytes);
		files[strip] = sha1(bytes);
		if (wavAt) { mkdirSync(path.join(wavAt, id), { recursive: true }); wav(path.join(wavAt, id, `${strip}.wav`), m[strip]); }
	}
	// Strips of an older layout left behind would confuse the player.
	for (const file of readdirSync(live)) if (file.endsWith('.ogg') && !STRIPS.includes(file.slice(0, -4))) rmSync(path.join(live, file));
	const record = { spec: { id, from: specId, name: spec.name, key: spec.key, mode: spec.mode, bpm: spec.bpm, meter: spec.meter, seed: spec.seed, bars: spec.bars || 24 },
		baked: new Date().toISOString(), rate: RATE, seconds: m.seconds, engine: 'tools/sound/synth.js', files, notes: { layers: STRIPS } };
	writeFileSync(path.join(live, 'render.json'), JSON.stringify(record) + '\n');
	console.log(`${id.padEnd(20)} ${spec.name.padEnd(22)} ${m.seconds.toFixed(1)} s  ${STRIPS.length} strips  ${Date.now() - began} ms`);
}
if (!ids.length) {
	// Everything in audio/music that is not a piece of the score or the air is retired.
	for (const dir of readdirSync(LIVE_DIR)) {
		if (dir === 'air' || wanted.includes(dir)) continue;
		if (existsSync(path.join(LIVE_DIR, dir, 'render.json')) || readdirSync(path.join(LIVE_DIR, dir)).some((f) => f.endsWith('.ogg'))) {
			rmSync(path.join(LIVE_DIR, dir), { recursive: true });
			console.log(`retired ${dir}`);
		}
	}
}
process.exit(failed ? 1 : 0);
