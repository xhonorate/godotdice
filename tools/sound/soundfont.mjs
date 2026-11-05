// The game's instruments as a SoundFont, so a DAW can play the score's notes (`stems.mjs`
// writes them as MIDI) with the voices the game wrote them for: every pad, bass, lead and
// sequence voice of the score engine sampled at five pitches, the kit's drums as a drum
// preset, and the interface's ping as an instrument of its own.
//
//   node tools/sound/soundfont.mjs [<out.sf2>] [--rate 44100]
//
// The default is build/daw/deep_cut.sf2. Load it in FL Studio's Fruity Soundfont Player (or
// any SF2 player): preset 0 to N are the voices in the order printed, bank 128 preset 0 the
// drums on General MIDI notes.

import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '../..');
const args = process.argv.slice(2);
const rateArg = args.includes('--rate') ? Number(args[args.indexOf('--rate') + 1]) : 44100;
const outFile = path.resolve(ROOT, args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--rate')[0] || 'build/daw/deep_cut.sf2');
globalThis.DEEP_SOUND_RATE = rateArg;
createRequire(import.meta.url)(path.join(here, 'synth.js'));
const C = globalThis.DeepSoundCore, M = globalThis.DeepSoundMV2, K = M._k, M3 = globalThis.DeepSoundMV3;
const RATE = C.RATE;

// --- what goes in ---------------------------------------------------------------------------------

// The voices are `(hz, seconds) -> Float32Array`: a note held `seconds` and let go. Sustaining
// ones get a loop inside the held part and a release of their own; struck ones play through.
const voices = Object.assign({}, K.V, (M3 && M3._k3 && M3._k3.V3) || {});
const sustained = new Set(['pad_warm', 'pad_glass', 'pad_dark', 'pad_choir', 'heat', 'lead_soft', 'lead_saw', 'lead_hum', 'lead_horn', 'bass_moog', 'bass_sub', 'bass_dirt', 'counter', 'brass', 'drone', 'seq_soft', 'seq_open']);
const struck = new Set(['lead_ping', 'lead_bell', 'seq_drip']);
const HOLD = 1.6, LOOP_FROM = 0.7, LOOP_TO = 1.45;
const ROOTS = [36, 48, 60, 72, 84];
const pingVoice = (hz, s) => { const y = new C.Syn(Math.min(2.5, 60 / (Math.PI * hz) * 7) + 0.1, 500); K.ping(y, 0, hz, 60, 0.4, 0.03); return y.b; };
const melodic = [...Object.keys(voices).filter((n) => sustained.has(n) || struck.has(n)), 'ping'];
const drums = [['kick', () => K.kick()], ['snare', () => K.snare()], ['hat', () => K.hat()], ['shaker', () => K.shaker()], ['clap', () => K.clap()], ['tom', () => K.tom(120)],
	['taiko', () => C.Drums.taiko()], ['anvil', () => C.Drums.anvil({ hz: 640, amp: 0.3 })], ['wood', () => C.Drums.wood({ hz: 520, amp: 0.5 })], ['rim', () => C.Drums.rim()],
	['tick', () => C.Drums.tick()], ['thud', () => C.Drums.thud()], ['bodhran', () => C.Drums.bodhran()], ['stomp', () => C.Drums.stomp()]];
const GM = { kick: 36, snare: 38, hat: 42, shaker: 70, clap: 39, tom: 47, taiko: 41, anvil: 56, wood: 76, rim: 37, tick: 44, thud: 35, bodhran: 43, stomp: 48 };

// --- the file -------------------------------------------------------------------------------------

const chunk = (id, body) => { const pad = body.length & 1 ? Buffer.alloc(1) : Buffer.alloc(0); const head = Buffer.alloc(8); head.write(id, 0, 'ascii'); head.writeUInt32LE(body.length, 4); return Buffer.concat([head, body, pad]); };
const list = (kind, chunks) => chunk('LIST', Buffer.concat([Buffer.from(kind, 'ascii'), ...chunks]));
const name20 = (s) => { const b = Buffer.alloc(20); b.write(s.slice(0, 19), 0, 'ascii'); return b; };
const timecents = (seconds) => Math.max(-12000, Math.min(8000, Math.round(1200 * Math.log2(Math.max(0.001, seconds)))));
const GEN = { keyRange: 43, sampleModes: 54, releaseVolEnv: 38, sampleID: 53, instrument: 41, attackVolEnv: 34 };

function build() {
	const samples = []; // {name, data: Int16, loopStart, loopEnd, rate, root}
	const insts = [];   // {name, zones: [{lo, hi, sample, loop, release, attack}]}
	const presets = []; // {name, bank, preset, inst}
	for (const vname of melodic) {
		const voice = vname === 'ping' ? pingVoice : voices[vname];
		const zones = [];
		ROOTS.forEach((root, i) => {
			const hz = 440 * Math.pow(2, (root - 69) / 12);
			const b = voice(hz, HOLD);
			let end = b.length; while (end > 1 && Math.abs(b[end - 1]) < 1e-4) end--;
			const data = new Int16Array(end);
			for (let k = 0; k < end; k++) data[k] = Math.max(-32767, Math.min(32767, Math.round(b[k] * 32767)));
			const loop = sustained.has(vname);
			samples.push({ name: `${vname}_${root}`, data, loopStart: loop ? Math.round(LOOP_FROM * RATE) : 0, loopEnd: loop ? Math.min(end - 1, Math.round(LOOP_TO * RATE)) : end - 1, rate: RATE, root });
			zones.push({ lo: i === 0 ? 0 : root - 6, hi: i === ROOTS.length - 1 ? 127 : root + 5, sample: samples.length - 1, loop, release: loop ? 0.6 : 0.05, attack: 0 });
		});
		insts.push({ name: vname, zones });
		presets.push({ name: vname, bank: 0, preset: presets.length, inst: insts.length - 1 });
	}
	const drumZones = [];
	for (const [dname, make] of drums) {
		const b = make();
		let end = b.length; while (end > 1 && Math.abs(b[end - 1]) < 1e-4) end--;
		const data = new Int16Array(end);
		for (let k = 0; k < end; k++) data[k] = Math.max(-32767, Math.min(32767, Math.round(b[k] * 32767)));
		const note = GM[dname] ?? 60;
		samples.push({ name: `drum_${dname}`, data, loopStart: 0, loopEnd: end - 1, rate: RATE, root: note });
		drumZones.push({ lo: note, hi: note, sample: samples.length - 1, loop: false, release: 0.05, attack: 0 });
	}
	insts.push({ name: 'drums', zones: drumZones });
	presets.push({ name: 'Deep Cut drums', bank: 128, preset: 0, inst: insts.length - 1 });

	// sdta: every sample, 46 zero samples after each, offsets kept in frames.
	const offsets = []; let total = 0;
	for (const s of samples) { offsets.push(total); total += s.data.length + 46; }
	const smpl = Buffer.alloc(total * 2);
	samples.forEach((s, i) => { for (let k = 0; k < s.data.length; k++) smpl.writeInt16LE(s.data[k], (offsets[i] + k) * 2); });

	// pdta: presets, their bags and generators; instruments, their bags and generators; sample headers.
	const phdr = [], pbag = [], pgen = [], inst = [], ibag = [], igen = [];
	const gen = (op, value) => { const b = Buffer.alloc(4); b.writeUInt16LE(op, 0); if (op === GEN.keyRange) { b[2] = value[0]; b[3] = value[1]; } else b.writeInt16LE(value, 2); return b; };
	for (const p of presets) {
		const h = Buffer.alloc(38); name20(p.name).copy(h, 0); h.writeUInt16LE(p.preset, 20); h.writeUInt16LE(p.bank, 22); h.writeUInt16LE(pbag.length, 24); h.writeUInt32LE(0, 26); h.writeUInt32LE(0, 30); h.writeUInt32LE(0, 34);
		phdr.push(h);
		const bag = Buffer.alloc(4); bag.writeUInt16LE(pgen.length, 0); bag.writeUInt16LE(0, 2); pbag.push(bag);
		pgen.push(gen(GEN.instrument, p.inst));
	}
	const eop = Buffer.alloc(38); name20('EOP').copy(eop, 0); eop.writeUInt16LE(pbag.length, 24); phdr.push(eop);
	const pbagEnd = Buffer.alloc(4); pbagEnd.writeUInt16LE(pgen.length, 0); pbag.push(pbagEnd);
	pgen.push(Buffer.alloc(4));
	for (const it of insts) {
		const h = Buffer.alloc(22); name20(it.name).copy(h, 0); h.writeUInt16LE(ibag.length, 20); inst.push(h);
		for (const z of it.zones) {
			const bag = Buffer.alloc(4); bag.writeUInt16LE(igen.length, 0); bag.writeUInt16LE(0, 2); ibag.push(bag);
			igen.push(gen(GEN.keyRange, [z.lo, z.hi]));
			if (z.attack > 0) igen.push(gen(GEN.attackVolEnv, timecents(z.attack)));
			igen.push(gen(GEN.releaseVolEnv, timecents(z.release)));
			igen.push(gen(GEN.sampleModes, z.loop ? 1 : 0));
			igen.push(gen(GEN.sampleID, z.sample));
		}
	}
	const eoi = Buffer.alloc(22); name20('EOI').copy(eoi, 0); eoi.writeUInt16LE(ibag.length, 20); inst.push(eoi);
	const ibagEnd = Buffer.alloc(4); ibagEnd.writeUInt16LE(igen.length, 0); ibag.push(ibagEnd);
	igen.push(Buffer.alloc(4));
	const shdr = samples.map((s, i) => {
		const h = Buffer.alloc(46); name20(s.name).copy(h, 0);
		h.writeUInt32LE(offsets[i], 20); h.writeUInt32LE(offsets[i] + s.data.length, 24);
		h.writeUInt32LE(offsets[i] + s.loopStart, 28); h.writeUInt32LE(offsets[i] + s.loopEnd, 32);
		h.writeUInt32LE(s.rate, 36); h[40] = s.root; h[41] = 0; h.writeUInt16LE(0, 42); h.writeUInt16LE(1, 44);
		return h;
	});
	const eos = Buffer.alloc(46); name20('EOS').copy(eos, 0); shdr.push(eos);
	const pmod = Buffer.alloc(10), imod = Buffer.alloc(10);
	const ifil = Buffer.alloc(4); ifil.writeUInt16LE(2, 0); ifil.writeUInt16LE(1, 2);
	const z = (s) => Buffer.from(s + '\0' + (s.length % 2 ? '' : '\0'), 'ascii');
	const info = list('INFO', [chunk('ifil', ifil), chunk('isng', z('EMU8000')), chunk('INAM', z('Deep Cut')), chunk('IENG', z('tools/sound/soundfont.mjs')), chunk('ICMT', z(`The voices of Deep Cut's score and interface, sampled from the game's own synthesis at ${RATE} Hz.`))]);
	const sdta = list('sdta', [chunk('smpl', smpl)]);
	const pdta = list('pdta', [chunk('phdr', Buffer.concat(phdr)), chunk('pbag', Buffer.concat(pbag)), chunk('pmod', pmod), chunk('pgen', Buffer.concat(pgen)),
		chunk('inst', Buffer.concat(inst)), chunk('ibag', Buffer.concat(ibag)), chunk('imod', imod), chunk('igen', Buffer.concat(igen)), chunk('shdr', Buffer.concat(shdr))]);
	const body = Buffer.concat([Buffer.from('sfbk', 'ascii'), info, sdta, pdta]);
	const file = Buffer.concat([chunk('RIFF', body)]);
	return { file, presets, samples, bytes: file.length };
}

mkdirSync(path.dirname(outFile), { recursive: true });
const { file, presets, samples, bytes } = build();
writeFileSync(outFile, file);
console.log(`${outFile}: ${presets.length} presets, ${samples.length} samples, ${(bytes / 1048576).toFixed(1)} MB at ${RATE} Hz`);
presets.forEach((p) => console.log(`  bank ${String(p.bank).padStart(3)} preset ${String(p.preset).padStart(2)}  ${p.name}`));
