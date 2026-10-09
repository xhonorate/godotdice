// The soundtrack, outside the game: the score, the pieces baked from it, drafts of new
// versions, the Godot renders that make them, and MIDI out of any of them.
//
// A piece lives in three places:
//   content/score.json             its spec: key, mode, tempo, chords, voices, seed (what the
//                                  game names it by and the editor edits)
//   audio/music/<id>/<layer>.ogg   the live version, one loop a layer, what the game plays;
//                                  render.json beside them records the spec they were baked
//                                  from, every note in them and a hash of each file, so a
//                                  layer replaced by hand (a DAW master) is told apart
//   build/music/drafts/<id>/       a version being tried: spec.json as edited, the layers as
//                                  WAV and notes.json once rendered. Adopting it encodes the
//                                  WAVs over the live files and writes its spec to the score;
//                                  discarding it deletes the folder.
//
// The air of each cave is baked the same way to audio/music/air/<family>.ogg, by `bake` only.
//
// As a command:
//   node tools/data-browser/music.mjs bake [id ...] [--air] [--force]
// bakes the named pieces (all of them, and the air, if none are named) from the score into the
// live files. A piece with a layer replaced by hand is skipped unless --force.

import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, readdirSync } from 'node:fs';
import { mkdir, readFile, writeFile, rm, readdir, rename, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createOggEncoder } from 'wasm-media-encoders';

const here = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(here, '../..');
export const SCORE_FILE = path.join(ROOT, 'content/score.json');
export const LIVE_DIR = path.join(ROOT, 'audio/music');
export const DRAFT_DIR = path.join(ROOT, 'build/music/drafts');
const RENDER_DIR = path.join(ROOT, 'build/music/render');

// As DeepComposer.LAYERS: the six strips of every piece, in order.
export const LAYERS = ['bed', 'pulse', 'melody', 'drive', 'threat', 'peril'];
// Fields the game reads while it plays rather than baked into the sound: changing one needs no
// render, and a draft that changes only these can be adopted as it stands.
export const RUNTIME_FIELDS = ['name', 'warden_lift'];
export const AIRS = ['workshop', 'galleries', 'seeps', 'crystal', 'fungal', 'magma', 'geode', 'rift'];
// Vorbis quality, -1 to 10: 6 is transparent for these mono loops at about 80 kbit/s.
const OGG_QUALITY = 6;
// The order a track's fields are written in, so a diff of the score shows only what changed.
const FIELD_ORDER = ['name', 'key', 'mode', 'bpm', 'meter', 'seed', 'chords', 'bridge', 'pad', 'bass', 'bass_style', 'lead', 'lead_octave',
	'arp', 'arp_rate', 'kit', 'layers', 'drone', 'sevenths', 'echo', 'warden_lift'];

export const validId = (id) => /^[a-z0-9_]+$/.test(String(id));

// A spec as far as the sound is concerned: what a render depends on.
export function audible(spec) {
	const out = orderTrack(spec || {});
	for (const key of RUNTIME_FIELDS) delete out[key];
	return JSON.stringify(out);
}

// --- the score --------------------------------------------------------------------------------

export async function readScore() {
	return JSON.parse(await readFile(SCORE_FILE, 'utf8'));
}

export function orderTrack(spec) {
	const out = {};
	for (const key of FIELD_ORDER) if (spec[key] !== undefined) out[key] = spec[key];
	for (const key of Object.keys(spec).sort()) if (out[key] === undefined && spec[key] !== undefined) out[key] = spec[key];
	return out;
}

// One place and one track a line: the file reads as a table and diffs a piece at a time.
export function formatScore(score) {
	const lines = ['{'];
	lines.push(`\t"about": ${JSON.stringify(score.about || '')},`);
	lines.push('\t"places": {');
	const places = Object.entries(score.places || {});
	places.forEach(([key, place], i) => lines.push(`\t\t${JSON.stringify(key)}: ${inline(place)}${i < places.length - 1 ? ',' : ''}`));
	lines.push('\t},');
	lines.push('\t"tracks": {');
	const tracks = Object.entries(score.tracks || {});
	tracks.forEach(([id, spec], i) => lines.push(`\t\t${JSON.stringify(id)}: ${inline(orderTrack(spec))}${i < tracks.length - 1 ? ',' : ''}`));
	lines.push('\t}');
	lines.push('}');
	return lines.join('\n') + '\n';
}

function inline(value) {
	if (Array.isArray(value)) return `[${value.map(inline).join(', ')}]`;
	if (value && typeof value === 'object') return `{${Object.entries(value).map(([k, v]) => `${JSON.stringify(k)}: ${inline(v)}`).join(', ')}}`;
	return JSON.stringify(value);
}

export async function writeScore(score) {
	await writeFile(SCORE_FILE, formatScore(score));
}

// --- Godot ------------------------------------------------------------------------------------

let godotPath;
export function findGodot() {
	if (godotPath !== undefined) return godotPath;
	const candidates = [process.env.GODOT_BIN];
	for (const name of ['godot', 'godot4']) {
		try { candidates.push(execFileSync(process.platform === 'win32' ? 'where' : 'which', [name], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).split(/\r?\n/)[0].trim()); } catch { /* not on the path */ }
	}
	// Where a Windows or Mac install usually sits: beside the project, on the desktop, in downloads.
	const home = process.env.USERPROFILE || process.env.HOME || '';
	for (const dir of [path.dirname(ROOT), path.join(home, 'Desktop'), path.join(home, 'Downloads'), path.join(home, 'Applications')]) {
		try {
			for (const file of readdirSync(dir)) {
				if (/^Godot_v4\.7\.2-stable_win64_console\.exe$/i.test(file)) candidates.push(path.join(dir, file));
			}
		} catch { /* no such folder */ }
	}
	candidates.push('/Applications/Godot.app/Contents/MacOS/Godot');
	godotPath = candidates.find((c) => c && existsSync(c)) || null;
	return godotPath;
}

function runGodot(args) {
	const godot = findGodot();
	if (!godot) return Promise.reject(new Error('Godot 4.7.2 was not found. Set GODOT_BIN to the console executable.'));
	return new Promise((resolve, reject) => {
		const child = spawn(godot, ['--headless', '--path', ROOT, '--script', 'res://tools/music_render.gd', '--', ...args], { cwd: ROOT, windowsHide: true });
		let log = '';
		child.stdout.on('data', (d) => { log += d; });
		child.stderr.on('data', (d) => { log += d; });
		child.on('error', reject);
		child.on('close', (code) => {
			const errors = log.split(/\r?\n/).filter((l) => /SCRIPT ERROR|^ERROR:|No piece called/.test(l));
			if (code !== 0 || errors.length) reject(new Error(errors.join('\n') || `Godot exited with ${code}\n${log.slice(-800)}`));
			else resolve(log);
		});
	});
}

// Render pieces, each from a spec file, into build/music/render/<id>/: one WAV a layer and
// notes.json. `jobs` is [[id, specFile]], or [['air:<family>']] for a cave's air.
async function render(jobs) {
	await mkdir(RENDER_DIR, { recursive: true });
	for (const [id] of jobs) await rm(path.join(RENDER_DIR, id.replace(':', '_')), { recursive: true, force: true });
	await runGodot([RENDER_DIR, ...jobs.map(([id, file]) => (file ? `${id}=${file}` : id))]);
}

// --- WAV and Ogg ------------------------------------------------------------------------------

function wavSamples(buffer) {
	// The 16-bit PCM mono the synth writes, as floats.
	let at = 12, rate = 24000, data = null;
	while (at + 8 <= buffer.length) {
		const id = buffer.toString('ascii', at, at + 4);
		const size = buffer.readUInt32LE(at + 4);
		if (id === 'fmt ') {
			if (buffer.readUInt16LE(at + 10) !== 1 || buffer.readUInt16LE(at + 22) !== 16) throw new Error('only 16-bit mono WAV is encoded');
			rate = buffer.readUInt32LE(at + 12);
		} else if (id === 'data') data = buffer.subarray(at + 8, at + 8 + size);
		at += 8 + size + (size & 1);
	}
	if (!data) throw new Error('WAV has no data');
	const out = new Float32Array(data.length >> 1);
	for (let i = 0; i < out.length; i++) out[i] = data.readInt16LE(i * 2) / 32768;
	return { rate, samples: out };
}

let encoder = null;
async function oggFrom(wavBuffer) {
	const { rate, samples } = wavSamples(wavBuffer);
	encoder ||= await createOggEncoder();
	// A fixed stream serial: the same render encodes to the same bytes, so git sees no change.
	encoder.configure({ channels: 1, sampleRate: rate, vbrQuality: OGG_QUALITY, oggSerialNo: 0x44454550 });
	const parts = [];
	for (let i = 0; i < samples.length; i += 16384) parts.push(Buffer.from(encoder.encode([samples.subarray(i, i + 16384)])));
	parts.push(Buffer.from(encoder.finalize()));
	return Buffer.concat(parts);
}

const sha1 = (buffer) => createHash('sha1').update(buffer).digest('hex');

// Encode a rendered piece's layers over its live files and write its record.
async function bakeFrom(renderDir, id, spec) {
	const live = path.join(LIVE_DIR, id);
	await mkdir(live, { recursive: true });
	const notes = JSON.parse(await readFile(path.join(renderDir, 'notes.json'), 'utf8'));
	const files = {};
	for (let i = 0; i < notes.layers.length; i++) {
		const ogg = await oggFrom(await readFile(path.join(renderDir, `${i}_${LAYERS[i]}.wav`)));
		await writeFile(path.join(live, `${LAYERS[i]}.ogg`), ogg);
		files[LAYERS[i]] = sha1(ogg);
	}
	// A piece written in fewer layers than it was leaves no stale strip behind.
	for (const name of LAYERS.slice(notes.layers.length)) await rm(path.join(live, `${name}.ogg`), { force: true });
	await writeFile(path.join(live, 'render.json'), JSON.stringify({ spec: orderTrack(spec), baked: new Date().toISOString(), files, notes }) + '\n');
}

// --- what is live -----------------------------------------------------------------------------

async function readJson(file) {
	try { return JSON.parse(await readFile(file, 'utf8')); } catch { return null; }
}

async function fileInfo(file) {
	try { const s = await stat(file); return { bytes: s.size, mtime: s.mtimeMs }; } catch { return null; }
}

export async function liveState(id, spec) {
	const dir = path.join(LIVE_DIR, id);
	const record = await readJson(path.join(dir, 'render.json'));
	const layers = [];
	for (const name of LAYERS) {
		const info = await fileInfo(path.join(dir, `${name}.ogg`));
		if (!info) continue;
		const hand = !record || !record.files || record.files[name] !== sha1(await readFile(path.join(dir, `${name}.ogg`)));
		layers.push({ name, bytes: info.bytes, url: `/music/live/${id}/${name}.ogg?v=${Math.round(info.mtime)}`, hand });
	}
	const wanted = Math.max(1, Math.min(LAYERS.length, Number(spec?.layers ?? LAYERS.length)));
	return {
		baked: layers.length > 0, complete: layers.length >= wanted, layers,
		bakedAt: record?.baked || null,
		// The score and the baked files can part ways (an edit by hand to the score): say so.
		matchesScore: !!record && audible(record.spec) === audible(spec),
		hasNotes: !!record?.notes,
	};
}

export async function draftState(id) {
	const dir = path.join(DRAFT_DIR, id);
	const spec = await readJson(path.join(dir, 'spec.json'));
	if (!spec) return null;
	const rendered = await readJson(path.join(dir, 'rendered.json'));
	const baked = await readJson(path.join(LIVE_DIR, id, 'render.json'));
	const layers = [];
	if (rendered) {
		for (let i = 0; i < rendered.layers; i++) {
			const info = await fileInfo(path.join(dir, `${i}_${LAYERS[i]}.wav`));
			if (info) layers.push({ name: LAYERS[i], bytes: info.bytes, url: `/music/draft/${id}/${i}_${LAYERS[i]}.wav?v=${Math.round(info.mtime)}` });
		}
	}
	return {
		spec, layers, rendered: !!rendered && layers.length === rendered.layers,
		renderedAt: rendered?.at || null, renderMs: rendered?.ms || null,
		stale: !rendered || audible(rendered.spec) !== audible(spec),
		// Changes only what the game reads at play time (a name, the Warden key change): the
		// live files already sound like this draft, so it can be adopted without a render.
		runtimeOnly: !!baked && audible(baked.spec) === audible(spec),
		error: rendered?.error || null,
	};
}

// --- drafts -----------------------------------------------------------------------------------

export async function saveDraft(id, spec) {
	const dir = path.join(DRAFT_DIR, id);
	await mkdir(dir, { recursive: true });
	await writeFile(path.join(dir, 'spec.json'), JSON.stringify(orderTrack(spec), null, '\t') + '\n');
}

export async function discardDraft(id) {
	await rm(path.join(DRAFT_DIR, id), { recursive: true, force: true });
}

export async function renderDraft(id) {
	const dir = path.join(DRAFT_DIR, id);
	const specFile = path.join(dir, 'spec.json');
	const spec = await readJson(specFile);
	if (!spec) throw new Error(`${id} has no draft`);
	const began = Date.now();
	try {
		await render([[id, specFile]]);
	} catch (error) {
		await writeFile(path.join(dir, 'rendered.json'), JSON.stringify({ spec, at: new Date().toISOString(), layers: 0, error: String(error.message || error) }));
		throw error;
	}
	const out = path.join(RENDER_DIR, id);
	const notes = JSON.parse(await readFile(path.join(out, 'notes.json'), 'utf8'));
	for (const file of await readdir(dir)) if (file.endsWith('.wav') || file === 'notes.json') await rm(path.join(dir, file), { force: true });
	for (const file of await readdir(out)) await rename(path.join(out, file), path.join(dir, file));
	await writeFile(path.join(dir, 'rendered.json'), JSON.stringify({ spec, at: new Date().toISOString(), ms: Date.now() - began, layers: notes.layers.length }));
}

// The draft becomes the live version: its layers encoded over the live files, its spec into
// the score.
export async function adoptDraft(id) {
	const state = await draftState(id);
	if (!state) throw new Error(`${id} has no draft`);
	if (state.rendered && !state.stale) {
		// A render is what was heard, and it may differ from the live files even for the same
		// spec (the synth itself changed): bake it.
		await bakeFrom(path.join(DRAFT_DIR, id), id, state.spec);
	} else if (state.runtimeOnly) {
		// Nothing to bake: the record keeps the sound's spec, the score takes the new fields.
		const file = path.join(LIVE_DIR, id, 'render.json');
		const record = await readJson(file);
		record.spec = orderTrack(state.spec);
		await writeFile(file, JSON.stringify(record) + '\n');
	} else {
		throw new Error('Render the draft before adopting it');
	}
	const score = await readScore();
	score.tracks[id] = orderTrack(state.spec);
	await writeScore(score);
	await discardDraft(id);
}

export async function notesFor(id, version) {
	if (version === 'draft') return readJson(path.join(DRAFT_DIR, id, 'notes.json'));
	return (await readJson(path.join(LIVE_DIR, id, 'render.json')))?.notes || null;
}

// --- the render queue -------------------------------------------------------------------------
// One render at a time (each takes all of a core for a few seconds). Asking again for a piece
// already waiting changes nothing; asking for the one rendering queues it once more, since its
// spec may have moved on since it started.

const queue = { running: null, waiting: [], last: null, changes: 0 };
export function queueState() { return { running: queue.running, waiting: queue.waiting.slice(), last: queue.last, changes: queue.changes }; }
export function enqueue(id) {
	if (!queue.waiting.includes(id)) queue.waiting.push(id);
	queue.changes++;
	pump();
}
export function touched() { queue.changes++; }
async function pump() {
	if (queue.running || !queue.waiting.length) return;
	const id = queue.waiting.shift();
	queue.running = id;
	const began = Date.now();
	try {
		await renderDraft(id);
		queue.last = { id, ok: true, ms: Date.now() - began };
	} catch (error) {
		queue.last = { id, ok: false, ms: Date.now() - began, error: String(error.message || error) };
	}
	queue.running = null;
	queue.changes++;
	pump();
}

// --- MIDI -------------------------------------------------------------------------------------
// A Type 1 file: a conductor track (tempo, metre, key, the plan as markers), then one track for
// each voice in each layer, so a DAW shows the layers the game fades between. Sixteenths are the
// grid, at 24 ticks each.

const PPQ = 96;
const TICKS_PER_STEP = PPQ / 4;
const PLAN = ['A', 'A2', 'B', 'ans', 'A', 'A2', 'B2', 'end', 'C', 'C2', 'B', 'end'];
// The General MIDI programs nearest each of the synth's voices.
const PROGRAMS = { pad_warm: 89, pad_glass: 94, pad_choir: 91, pad_dark: 95, bass_sub: 38, bass_pluck: 32, bass_saw: 39, lead_flute: 73,
	lead_bell: 14, lead_glass: 98, lead_pluck: 24, lead_marimba: 12, lead_reed: 68, brass: 61, strings: 44, drone: 89,
	spiccato: 48, horn: 60, braam: 58, timpani: 47 };
// The General MIDI drum nearest each of the kits' drums.
const DRUMS = { kick: 36, taiko: 35, thud: 35, tom: 45, rim: 37, snare: 38, wood_low: 77, wood: 76, anvil: 56, shaker: 70, hat: 42,
	tick: 76, tick_low: 77, frame: 63, drip: 75, drip_low: 77, chime: 81, swell: 49 };
const MAJOR_FROM_MODE = { ionian: 0, dorian: 2, phrygian: 4, lydian: 5, mixolydian: 7, aeolian: 9, locrian: 11, harmonic: 9, phrygian_dominant: 4 };
const SHARPS = { 0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6, 1: -5, 8: -4, 3: -3, 10: -2, 5: -1 };
const PITCHES = { C: 0, 'C#': 1, Db: 1, D: 2, 'D#': 3, Eb: 3, E: 4, F: 5, 'F#': 6, Gb: 6, G: 7, 'G#': 8, Ab: 8, A: 9, 'A#': 10, Bb: 10, B: 11 };

function varLen(n) {
	const bytes = [n & 0x7f];
	while ((n >>= 7)) bytes.unshift((n & 0x7f) | 0x80);
	return bytes;
}
function chunk(type, bytes) {
	const head = Buffer.alloc(8);
	head.write(type, 0, 'ascii');
	head.writeUInt32BE(bytes.length, 4);
	return Buffer.concat([head, Buffer.from(bytes)]);
}
function trackBytes(events) {
	// events: [tick, order, bytes]; at one tick, note-offs (order 0) go before note-ons.
	events.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
	const out = [];
	let now = 0;
	for (const [tick, , bytes] of events) {
		out.push(...varLen(tick - now), ...bytes);
		now = tick;
	}
	out.push(0, 0xff, 0x2f, 0);
	return out;
}
const text = (type, s) => { const b = [...Buffer.from(s, 'utf8')]; return [0xff, type, ...varLen(b.length), ...b]; };

export function midiFrom(notes, spec, title) {
	const meter = Number(notes.meter) || 4;
	const stepsBar = meter * 4;
	const conductor = [[0, 1, text(0x03, title)], [0, 1, [0xff, 0x51, 3, ...(() => { const us = Math.round(60000000 / Number(spec.bpm || 90)); return [(us >> 16) & 255, (us >> 8) & 255, us & 255]; })()]],
		[0, 1, [0xff, 0x58, 4, meter, 2, 24, 8]]];
	const major = ((PITCHES[spec.key] ?? 0) - (MAJOR_FROM_MODE[spec.mode] ?? 9) + 12) % 12;
	conductor.push([0, 1, [0xff, 0x59, 2, SHARPS[major] & 0xff, 0]]);
	PLAN.forEach((part, slot) => conductor.push([slot * 2 * stepsBar * TICKS_PER_STEP, 1, text(0x06, part)]));
	const groups = new Map();
	for (const [layer, voice, midi, at, steps, level] of notes.notes) {
		const drum = voice.startsWith('drum:');
		const key = drum ? `${layer}|drums` : `${layer}|${voice}`;
		if (!groups.has(key)) groups.set(key, { layer, voice: drum ? 'drums' : voice, drum, notes: [] });
		groups.get(key).notes.push({ pitch: drum ? (DRUMS[voice.split(':')[2]] ?? 39) : midi, at, steps: drum ? 1 : steps, level });
	}
	const tracks = [trackBytes(conductor)];
	// Every voice its own channel, round the fifteen that are not the drums'.
	let nextChannel = 0;
	const takeChannel = () => { if (nextChannel === 9) nextChannel++; const ch = nextChannel; nextChannel = (nextChannel + 1) % 16; return ch; };
	for (const group of [...groups.values()].sort((a, b) => a.layer - b.layer || Number(a.drum) - Number(b.drum))) {
		const ch = group.drum ? 9 : takeChannel();
		const loudest = Math.max(...group.notes.map((n) => n.level), 0.0001);
		// The threat layer's drums are the same taiko and cymbal whatever the piece's kit.
		const kit = notes.layers[group.layer] === 'threat' ? 'taiko' : (spec.kit || 'frame');
		const events = [[0, 0, text(0x03, `${notes.layers[group.layer]} · ${group.drum ? `drums (${kit})` : group.voice}`)]];
		if (!group.drum) events.push([0, 0, [0xc0 | ch, PROGRAMS[group.voice] ?? 0]]);
		for (const n of group.notes) {
			const vel = Math.max(1, Math.min(127, Math.round(20 + 107 * n.level / loudest)));
			const on = n.at * TICKS_PER_STEP;
			events.push([on, 1, [0x90 | ch, n.pitch & 127, vel]], [on + n.steps * TICKS_PER_STEP, 0, [0x80 | ch, n.pitch & 127, 0]]);
		}
		tracks.push(trackBytes(events));
	}
	const header = Buffer.alloc(6);
	header.writeUInt16BE(1, 0);
	header.writeUInt16BE(tracks.length, 2);
	header.writeUInt16BE(PPQ, 4);
	return Buffer.concat([chunk('MThd', [...header]), ...tracks.map((t) => chunk('MTrk', t))]);
}

// --- bake -------------------------------------------------------------------------------------

export async function bake({ ids = [], air = false, force = false, log = console.log } = {}) {
	const score = await readScore();
	const all = ids.length === 0 && !air;
	const wanted = all ? Object.keys(score.tracks) : ids;
	const jobs = [];
	await mkdir(path.join(RENDER_DIR, 'specs'), { recursive: true });
	for (const id of wanted) {
		const spec = score.tracks[id];
		if (!spec) throw new Error(`No piece called ${id}`);
		const live = await liveState(id, spec);
		if (!force && live.layers.some((l) => l.hand)) {
			log(`${id}: skipped, ${live.layers.filter((l) => l.hand).map((l) => l.name).join(', ')} replaced by hand (--force bakes over it)`);
			continue;
		}
		const file = path.join(RENDER_DIR, 'specs', `${id}.json`);
		await writeFile(file, JSON.stringify(spec));
		jobs.push([id, file]);
	}
	const airs = all || air ? AIRS : [];
	if (jobs.length || airs.length) {
		log(`Rendering ${jobs.length} pieces${airs.length ? ` and ${airs.length} airs` : ''}…`);
		await render([...jobs, ...airs.map((family) => [`air:${family}`])]);
	}
	for (const [id] of jobs) {
		await bakeFrom(path.join(RENDER_DIR, id), id, score.tracks[id]);
		log(`${id}: baked`);
	}
	if (airs.length) await mkdir(path.join(LIVE_DIR, 'air'), { recursive: true });
	for (const family of airs) {
		await writeFile(path.join(LIVE_DIR, 'air', `${family}.ogg`), await oggFrom(await readFile(path.join(RENDER_DIR, 'air', `${family}.wav`))));
		log(`air:${family}: baked`);
	}
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
	const [command, ...rest] = process.argv.slice(2);
	if (command !== 'bake') {
		console.log('Usage: node tools/data-browser/music.mjs bake [id ...] [--air] [--force]');
		process.exit(2);
	}
	bake({ ids: rest.filter((a) => !a.startsWith('--')), air: rest.includes('--air'), force: rest.includes('--force') })
		.catch((error) => { console.error(error.message || error); process.exit(1); });
}
