// The score, split for a DAW: a piece written out as its four strips, every instrument in
// them as a stem of its own, and the notes as a MIDI file, one track an instrument, so the
// piece can be opened in FL Studio as it is, re-voiced, mixed and bounced back a strip at a
// time (`import.mjs` brings a bounce in).
//
//   node tools/sound/stems.mjs <id> [<out dir>] [--rate 44100]
//   node tools/sound/stems.mjs --bank [<out dir>] [--rate 44100]
//
// Writes <out>/<id>/<strip>.wav (bed, deep, fight, warden, as the game plays them), the
// stems to <out>/<id>/stems/<strip>-<part>.wav, <out>/<id>/<id>.mid and manifest.json. The
// default out dir is build/daw. --bank writes every sound in the bank instead, as WAV, to
// <out>/bank/. The DAW's rate (44.1 kHz) is the default; the game's own is 24000.

import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { PICKS, SPEC_OF } from './picks.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '../..');
const args = process.argv.slice(2);
const rateArg = args.includes('--rate') ? Number(args[args.indexOf('--rate') + 1]) : 44100;
const positional = args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--rate');
globalThis.DEEP_SOUND_RATE = rateArg;
createRequire(import.meta.url)(path.join(here, 'synth.js'));
const D = globalThis.DeepSound3, C = globalThis.DeepSoundCore;
const RATE = C.RATE;
const STRIPS = ['bed', 'deep', 'fight', 'warden'];

export function wav(file, channels, rate) {
	// `channels` is one Float32Array (mono) or two (stereo).
	const chans = Array.isArray(channels) ? channels : [channels];
	const n = chans[0].length, nc = chans.length, buf = Buffer.alloc(44 + n * nc * 2);
	buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * nc * 2, 4); buf.write('WAVE', 8); buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(nc, 22);
	buf.writeUInt32LE(rate, 24); buf.writeUInt32LE(rate * nc * 2, 28); buf.writeUInt16LE(nc * 2, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * nc * 2, 40);
	let at = 44;
	for (let i = 0; i < n; i++) for (let c = 0; c < nc; c++) { buf.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(chans[c][i] * 32767))), at); at += 2; }
	writeFileSync(file, buf);
}

// --- capturing a piece as it is written ----------------------------------------------------------

// Every note goes through Piece.play (a pitched voice) or Piece.hit (a drum), and every strip
// is levelled through Syn.rmsTo: wrapping those three is enough to keep each instrument's
// notes in a strip of its own, at the strip's final gain, and to list them for MIDI.
function capture() {
	const Piece = C.Piece, Syn = C.Syn;
	const state = { strips: [], parts: new Map(), notes: [] };
	const origStrip = Piece.prototype.strip, origPlay = Piece.prototype.play, origHit = Piece.prototype.hit, origRms = Syn.prototype.rmsTo;
	Piece.prototype.strip = function () { const s = origStrip.call(this); s._stem = state.strips.length; state.strips.push(s); return s; };
	const partOf = (piece, strip, name) => {
		const key = strip._stem + ':' + name;
		let part = state.parts.get(key);
		if (!part) { part = { strip: strip._stem, name, syn: origStrip.call(piece) }; state.parts.set(key, part); }
		return part.syn;
	};
	Piece.prototype.play = function (strip, name, voice, midi, step, lenSteps, level = 1) {
		origPlay.call(this, strip, name, voice, midi, step, lenSteps, level);
		if (strip._stem === undefined) return;
		const buf = this.memo(name + ':' + midi + ':' + lenSteps, () => voice(C.midiHz(midi), this.seconds(Math.max(1, lenSteps))));
		partOf(this, strip, name).add(buf, this.at(step), level);
		state.notes.push({ strip: strip._stem, name, midi, step, len: Math.max(1, lenSteps), level });
	};
	Piece.prototype.hit = function (strip, name, drum, step, level = 1, variant = 0) {
		origHit.call(this, strip, name, drum, step, level, variant);
		if (strip._stem === undefined) return;
		const buf = this.memo('drum:' + name + ':' + variant, () => drum(variant));
		partOf(this, strip, 'drum:' + name).add(buf, this.at(step), level);
		state.notes.push({ strip: strip._stem, name: 'drum:' + name, midi: 0, step, len: 1, level });
	};
	Syn.prototype.rmsTo = function (db) {
		const before = this.rms();
		origRms.call(this, db);
		if (this._stem !== undefined) this._gain = before > 1e-6 ? Math.pow(10, db / 20) / before : 1;
		return this;
	};
	state.release = () => { Piece.prototype.strip = origStrip; Piece.prototype.play = origPlay; Piece.prototype.hit = origHit; Syn.prototype.rmsTo = origRms; };
	return state;
}

// --- MIDI -----------------------------------------------------------------------------------------

const PPQ = 96, TICKS_PER_STEP = PPQ / 4;
// Drum names as General MIDI percussion, so a DAW's drum kit answers them until a better one is chosen.
const GM = { kick: 36, deepkick: 35, kickw: 36, back: 38, snare: 38, clap: 39, rim: 37, hat: 42, brush: 42, shaker: 70, perc: 45, tom: 47, tomw: 47, anvil: 56, tick: 42, wood: 76 };
function drumNote(name) {
	const role = name.split(':').pop();
	return GM[role] ?? 60;
}
const vlq = (n) => { const bytes = [n & 0x7f]; while ((n >>= 7) > 0) bytes.unshift((n & 0x7f) | 0x80); return Buffer.from(bytes); };
const be32 = (n) => { const b = Buffer.alloc(4); b.writeUInt32BE(n); return b; };
const be16 = (n) => { const b = Buffer.alloc(2); b.writeUInt16BE(n); return b; };
function track(events) {
	// events: [tick, bytes...] sorted; written with delta times and an end-of-track.
	events.sort((a, b) => a[0] - b[0]);
	const parts = []; let last = 0;
	for (const [tick, ...bytes] of events) { parts.push(vlq(tick - last), Buffer.from(bytes)); last = tick; }
	parts.push(vlq(0), Buffer.from([0xff, 0x2f, 0x00]));
	const body = Buffer.concat(parts);
	return Buffer.concat([Buffer.from('MTrk'), be32(body.length), body]);
}
export function midi(piece, notes, parts, name) {
	const tempo = Math.round(60000000 / piece.bpm);
	const meta = [[0, 0xff, 0x51, 0x03, (tempo >> 16) & 0xff, (tempo >> 8) & 0xff, tempo & 0xff], [0, 0xff, 0x58, 0x04, piece.meter, 2, 24, 8],
		[0, 0xff, 0x03, ...Buffer.from(name)].flatMap((v, i) => i === 3 ? [name.length] : [v])];
	const tracks = [track(meta.map((m) => (m.length > 3 && m[1] === 0xff && m[2] === 0x03) ? [0, 0xff, 0x03, name.length, ...Buffer.from(name)] : m))];
	let channel = 0;
	for (const part of parts) {
		const drum = part.name.startsWith('drum:');
		const ch = drum ? 9 : (channel++ % 15 >= 9 ? (channel % 15) + 1 : channel % 15);
		const label = `${STRIPS[part.strip] || part.strip}:${part.name.replace(/^drum:/, '')}`;
		const events = [[0, 0xff, 0x03, label.length, ...Buffer.from(label)]];
		for (const n of notes) {
			if (n.strip !== part.strip || n.name !== part.name) continue;
			const on = n.step * TICKS_PER_STEP, note = drum ? drumNote(n.name) : Math.max(0, Math.min(127, n.midi));
			const vel = Math.max(1, Math.min(127, Math.round(n.level * 100)));
			events.push([on, 0x90 | ch, note, vel], [on + (drum ? TICKS_PER_STEP / 2 : n.len * TICKS_PER_STEP) - 1, 0x80 | ch, note, 0]);
		}
		tracks.push(track(events));
	}
	return Buffer.concat([Buffer.from('MThd'), be32(6), be16(1), be16(tracks.length), be16(PPQ), ...tracks]);
}

// --- the piece ----------------------------------------------------------------------------------

export function renderPiece(id) {
	const score = JSON.parse(readFileSync(path.join(ROOT, 'content/score.json'), 'utf8'));
	const specId = score.tracks?.[id]?.from || SPEC_OF[id] || id;
	const spec = D.spec(specId);
	if (!spec) throw new Error(`No piece called ${id}`);
	const state = capture();
	let out;
	try { out = D.music(specId); } finally { state.release(); }
	const strips = STRIPS.map((s) => out[s]);
	const parts = [...state.parts.values()].map((part) => {
		// What the strip went through before it was levelled (the engine's lowpass and tape),
		// then the strip's own gain, so a stem sits where it sits in the mix.
		part.syn.lowpass(11000); part.syn.saturate(1.1);
		const gain = state.strips[part.strip]._gain ?? 1;
		const b = part.syn.b; for (let i = 0; i < b.length; i++) b[i] *= gain;
		return { strip: part.strip, name: part.name, samples: b };
	});
	const piece = { id, from: specId, name: spec.name, key: spec.key, mode: spec.mode, bpm: spec.bpm, meter: spec.meter || 4, bars: spec.bars || 24, rate: RATE, seconds: out.seconds };
	return { piece, strips, parts, notes: state.notes };
}

function writePiece(id, outDir) {
	const { piece, strips, parts, notes } = renderPiece(id);
	const dir = path.join(outDir, id), stemDir = path.join(dir, 'stems');
	mkdirSync(stemDir, { recursive: true });
	STRIPS.forEach((s, i) => wav(path.join(dir, `${s}.wav`), strips[i], RATE));
	const manifest = { ...piece, strips: STRIPS, stems: [], midi: `${id}.mid` };
	for (const part of parts) {
		const file = `${STRIPS[part.strip]}-${part.name.replace(/^drum:/, 'drum_').replace(/[^a-z0-9_]/gi, '_')}.wav`;
		wav(path.join(stemDir, file), part.samples, RATE);
		manifest.stems.push({ strip: STRIPS[part.strip], part: part.name, file: `stems/${file}` });
	}
	writeFileSync(path.join(dir, `${id}.mid`), midi(piece, notes, parts, `${piece.name} (${id})`));
	writeFileSync(path.join(dir, 'notes.json'), JSON.stringify({ ...piece, ticks_per_step: TICKS_PER_STEP, notes }));
	writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(manifest, null, 1));
	console.log(`${id.padEnd(20)} ${piece.name.padEnd(22)} ${piece.seconds.toFixed(1)} s at ${RATE} Hz  ${parts.length} stems  ${notes.length} notes  -> ${dir}`);
}

function writeBank(outDir) {
	const dir = path.join(outDir, 'bank');
	mkdirSync(dir, { recursive: true });
	const manifest = {};
	for (const name of D.NAMES) {
		const b = D.sfx(name, PICKS[name] ?? 0);
		wav(path.join(dir, `${name}.wav`), b, RATE);
		manifest[name] = { seconds: b.length / RATE, version: PICKS[name] ?? 'round 2' };
	}
	writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify({ rate: RATE, sounds: manifest }, null, 1));
	console.log(`${D.NAMES.length} sounds at ${RATE} Hz -> ${dir}`);
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
	if (args.includes('--bank')) writeBank(path.resolve(ROOT, positional[0] || 'build/daw'));
	else if (!positional[0]) { console.error('node tools/sound/stems.mjs <id> [<out dir>] [--rate 44100]   or   --bank [<out dir>]'); process.exit(2); }
	else writePiece(positional[0], path.resolve(ROOT, positional[1] || 'build/daw'));
}
