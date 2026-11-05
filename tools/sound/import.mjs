// A bounce from the DAW, brought back into the game.
//
//   node tools/sound/import.mjs music <id> <strip> <file.wav|.ogg>
//   node tools/sound/import.mjs music <id> <dir>            every <strip>.wav or .ogg found there
//   node tools/sound/import.mjs sound <name> <file.wav|.ogg>
//
// A music strip is written to audio/music/<id>/<strip>.ogg at the file's own rate and
// channels, cut or padded to exactly the piece's length (the other strips loop with it), and
// noted in render.json as replaced by hand. A sound is written to audio/sfx/<name>.ogg, which
// the bank plays instead of its recipe (`DeepSoundBank.OVERRIDES`). Either way the project has
// to be imported once afterwards (open it in the editor, or `godot --headless --import`), so
// Godot knows the new file.

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '../..');
const STRIPS = ['bed', 'deep', 'fight', 'warden'];
const GAME_RATE = 24000;
const OGG_QUALITY = 6;
const { createOggEncoder } = await import(pathToFileURL(path.join(ROOT, 'tools/data-browser/node_modules/wasm-media-encoders/dist/es/index.mjs')).href);

export function readWav(file) {
	// PCM 8, 16, 24 and 32 bit and 32-bit float, any channel count; as floats a channel.
	const buffer = readFileSync(file);
	if (buffer.toString('ascii', 0, 4) !== 'RIFF' || buffer.toString('ascii', 8, 12) !== 'WAVE') throw new Error(`${file} is not a WAV file`);
	let at = 12, format = null, data = null;
	while (at + 8 <= buffer.length) {
		const id = buffer.toString('ascii', at, at + 4), size = buffer.readUInt32LE(at + 4);
		if (id === 'fmt ') format = { tag: buffer.readUInt16LE(at + 8), channels: buffer.readUInt16LE(at + 10), rate: buffer.readUInt32LE(at + 12), bits: buffer.readUInt16LE(at + 22) };
		else if (id === 'data') data = buffer.subarray(at + 8, at + 8 + Math.min(size, buffer.length - at - 8));
		at += 8 + size + (size & 1);
	}
	if (!format || !data) throw new Error(`${file} has no format or no data`);
	const { channels, rate, bits } = format;
	const isFloat = format.tag === 3 || (format.tag === 0xfffe && bits === 32 && false);
	const frameBytes = channels * (bits / 8), frames = Math.floor(data.length / frameBytes);
	const out = Array.from({ length: channels }, () => new Float32Array(frames));
	for (let i = 0; i < frames; i++) for (let c = 0; c < channels; c++) {
		const p = i * frameBytes + c * (bits / 8);
		let v;
		if (format.tag === 3 || isFloat) v = data.readFloatLE(p);
		else if (bits === 16) v = data.readInt16LE(p) / 32768;
		else if (bits === 24) v = ((data[p] | (data[p + 1] << 8) | (data[p + 2] << 16)) << 8 >> 8) / 8388608;
		else if (bits === 32) v = data.readInt32LE(p) / 2147483648;
		else if (bits === 8) v = (data[p] - 128) / 128;
		else throw new Error(`${file}: ${bits}-bit PCM is not read`);
		out[c][i] = v;
	}
	return { rate, channels: out };
}

let encoder = null;
async function ogg(channels, rate) {
	encoder ||= await createOggEncoder();
	encoder.configure({ channels: channels.length, sampleRate: rate, vbrQuality: OGG_QUALITY, oggSerialNo: 0x44454550 });
	const parts = [], n = channels[0].length;
	for (let i = 0; i < n; i += 16384) parts.push(Buffer.from(encoder.encode(channels.map((c) => c.subarray(i, Math.min(n, i + 16384))))));
	parts.push(Buffer.from(encoder.finalize()));
	return Buffer.concat(parts);
}
const sha1 = (b) => createHash('sha1').update(b).digest('hex');

// The piece's length, as the game plays it: what render.json says, else what the score's tempo
// gives at the game's rate with the game's rounding.
function pieceSeconds(id) {
	const record = existsSync(path.join(ROOT, 'audio/music', id, 'render.json')) ? JSON.parse(readFileSync(path.join(ROOT, 'audio/music', id, 'render.json'), 'utf8')) : null;
	if (record && record.seconds) return record.seconds;
	const score = JSON.parse(readFileSync(path.join(ROOT, 'content/score.json'), 'utf8'));
	const spec = score.tracks?.[id];
	if (!spec) throw new Error(`No piece called ${id} in the score`);
	const meter = spec.meter === 3 ? 3 : 4, step = Math.round(GAME_RATE * 60 / spec.bpm / 4);
	return 24 * meter * 4 * step / GAME_RATE;
}

function fit(channels, frames) {
	// Cut or pad with silence to exactly `frames`, the last 8 ms faded so the cut is no click.
	return channels.map((c) => {
		const out = new Float32Array(frames);
		out.set(c.subarray(0, Math.min(c.length, frames)));
		const fade = Math.min(frames, 350);
		for (let i = 0; i < fade; i++) out[frames - 1 - i] *= i / fade;
		return out;
	});
}

async function readAny(file) {
	if (file.toLowerCase().endsWith('.ogg')) return { ogg: readFileSync(file) };
	return readWav(file);
}

export async function importStrip(id, strip, file) {
	if (!STRIPS.includes(strip)) throw new Error(`A strip is one of ${STRIPS.join(', ')}, not ${strip}`);
	const dir = path.join(ROOT, 'audio/music', id);
	mkdirSync(dir, { recursive: true });
	const seconds = pieceSeconds(id);
	const source = await readAny(file);
	let bytes, note;
	if (source.ogg) { bytes = source.ogg; note = 'an Ogg, taken as it is (its length is not checked)'; }
	else {
		const frames = Math.round(seconds * source.rate);
		const cut = source.channels[0].length - frames;
		bytes = await ogg(fit(source.channels, frames), source.rate);
		note = `${source.channels.length === 2 ? 'stereo' : source.channels.length === 1 ? 'mono' : source.channels.length + ' channels'} at ${source.rate} Hz, ${cut > 0 ? `${(cut / source.rate).toFixed(3)} s cut off the end` : cut < 0 ? `${(-cut / source.rate).toFixed(3)} s of silence added` : 'exactly the piece\'s length'}`;
	}
	writeFileSync(path.join(dir, `${strip}.ogg`), bytes);
	const recordFile = path.join(dir, 'render.json');
	const record = existsSync(recordFile) ? JSON.parse(readFileSync(recordFile, 'utf8')) : { files: {} };
	record.hand = record.hand || {};
	record.hand[strip] = { from: path.relative(ROOT, path.resolve(file)).replace(/\\/g, '/'), at: new Date().toISOString(), sha1: sha1(bytes) };
	writeFileSync(recordFile, JSON.stringify(record) + '\n');
	console.log(`${id}/${strip}.ogg written from ${path.basename(file)}: ${note}. Import the project once so Godot sees it.`);
}

export async function importSound(name, file) {
	const dir = path.join(ROOT, 'audio/sfx');
	mkdirSync(dir, { recursive: true });
	const source = await readAny(file);
	const bytes = source.ogg || await ogg(source.channels, source.rate);
	writeFileSync(path.join(dir, `${name}.ogg`), bytes);
	const recordFile = path.join(dir, 'hand.json');
	const record = existsSync(recordFile) ? JSON.parse(readFileSync(recordFile, 'utf8')) : {};
	record[name] = { from: path.relative(ROOT, path.resolve(file)).replace(/\\/g, '/'), at: new Date().toISOString(), sha1: sha1(bytes) };
	writeFileSync(recordFile, JSON.stringify(record, null, 1) + '\n');
	console.log(`audio/sfx/${name}.ogg written from ${path.basename(file)}; the bank plays it instead of the recipe once the project is imported.`);
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
	const [what, id, a, b] = process.argv.slice(2);
	try {
		if (what === 'music' && id && a && !b && existsSync(a) && statSync(a).isDirectory()) {
			let n = 0;
			for (const f of readdirSync(a)) { const strip = f.replace(/\.(wav|ogg)$/i, ''); if (STRIPS.includes(strip) && /\.(wav|ogg)$/i.test(f)) { await importStrip(id, strip, path.join(a, f)); n++; } }
			if (!n) throw new Error(`Nothing named bed, deep, fight or warden (.wav or .ogg) in ${a}`);
		} else if (what === 'music' && id && a && b) await importStrip(id, a, b);
		else if (what === 'sound' && id && a) await importSound(id, a);
		else { console.error('node tools/sound/import.mjs music <id> <strip> <file>   |   music <id> <dir>   |   sound <name> <file>'); process.exit(2); }
	} catch (e) { console.error(e.message); process.exit(1); }
}
