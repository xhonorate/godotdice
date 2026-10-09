// Holds the balance browser's fight (js/sim/fight.js) to the game's own rail. Writes seeded
// fixtures, has Godot play them with the real DeepBattle (tools/balance_parity.gd), plays the
// same fixtures here, and compares the state after every rail field by field.
//
//   node tools/data-browser/parity.mjs [--count 400] [--seed 1] [--keep]
//
// Exits 1 on any difference. Files go to build/parity/ (kept with --keep).

import { spawn, execFileSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';
import { mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as C from './js/sim/content.js';
import * as Dice from './js/sim/dice.js';
import * as Stone from './js/sim/stone.js';
import * as Fight from './js/sim/fight.js';
import { makeRng } from './js/sim/rng.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '../..');
const args = process.argv.slice(2);
const option = (name, fallback) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : fallback; };
const COUNT = Number(option('count', 400));
const SEED = Number(option('seed', 1));
const OUT = path.join(ROOT, 'build', 'parity');

C.setPack(JSON.parse(await readFile(path.join(ROOT, 'content', 'deep_cut.json'), 'utf8')));

// --- fixtures --------------------------------------------------------------------------------

// Live fixtures queue replays for real, so they keep to stones that never roll for a proc:
// one carat, no Flawless, nothing that changes a stone's weight mid-rail, no coin.
const LIVE_SKIP_SKILLS = ['ENRICH', 'FIRE_OPAL', 'STAKE', 'DOUBLE_DOWN', 'POLISH'];
const LIVE_SKIP_INCLUSIONS = ['FRACTURE', 'BRUISE', 'KNOT', 'CAVITY', 'CHIP', 'HALO', 'VOID'];

function fixtures(count, seed) {
	const rng = makeRng(seed * 7919 + 11);
	const pick = (list) => list[rng.randiRange(0, list.length - 1)];
	const characters = C.keys('characters');
	const skills = C.keys('skills');
	const inclusions = C.keys('inclusions').filter((k) => k !== 'VOID');
	const out = [];
	for (let n = 0; n < count; n++) {
		const live = n % 2 === 1;
		const character = pick(characters);
		const def = C.character(character);
		const sockets = def.sockets.length;
		const filled = rng.randiRange(1, sockets);
		const rail = Array.from({ length: sockets }, () => null);
		for (let i = 0; i < filled; i++) {
			const socket = rng.randf() < 0.85 ? i : rng.randiRange(0, sockets - 1);
			const pool = live ? skills.filter((k) => !LIVE_SKIP_SKILLS.includes(k)) : skills;
			const skill = pick(pool);
			const clarity = live ? pick([3, 4]) : rng.randiRange(0, 5);
			let slots = live ? (rng.randf() < 0.4 ? 1 : 0) : Stone.inclusionSlots(clarity);
			const allowed = live ? inclusions.filter((k) => !LIVE_SKIP_INCLUSIONS.includes(k)) : inclusions;
			const chosen = [];
			while (slots-- > 0) { const k = pick(allowed); if (!chosen.includes(k)) chosen.push(k); }
			rail[socket] = { skill, carat: live ? 1 : rng.randiRange(1, 24), cut: rng.randiRange(0, 4), clarity, inclusions: chosen, id: `g${socket}` };
		}
		const dice = def.dice.map((ref, i) => Dice.dieFrom(ref, `p${i}`));
		const runs = Array.from({ length: rng.randiRange(1, 3) }, () => ({ hand: dice.map((die) => { const rerolls = rng.randf() < 0.4 ? 1 : 0; return { face: rng.randiRange(0, die.faces.length - 1), rerolls, held: rerolls === 0 ? rng.randf() < 0.5 : true }; }) }));
		const enemy = () => ({ block: rng.randf() < 0.5 ? 0 : rng.randiRange(1, 10), statuses: { poison: rng.randiRange(0, 6), curse: rng.randiRange(0, 2), marked: rng.randiRange(0, 1) } });
		out.push({ id: n, mode: live ? 'live' : 'dry', seed: seed * 1000 + n, character, pyrite: rng.randiRange(0, 80), depth: 3, rail, runs,
			enemies: [enemy(), enemy()], unit: { hp: rng.randiRange(20, Number(def.hp)), block: rng.randiRange(0, 10), block_lost: rng.randiRange(0, 8), statuses: {},
				initial_resonance: rng.randiRange(0, 5), rerolls: rng.randiRange(0, 2) } });
	}
	return out;
}

// --- the JavaScript side ---------------------------------------------------------------------

const ints = (source) => Object.fromEntries(Object.entries(source || {}).filter(([, v]) => typeof v === 'number' && Math.trunc(v) !== 0).map(([k, v]) => [k, Math.trunc(v)]));

function play(f) {
	const def = C.character(f.character);
	const dice = def.dice.map((ref, i) => Dice.dieFrom(ref, `p${i}`));
	const rail = f.rail.map((s) => (s ? Stone.make(s.skill, s.carat, s.cut, s.clarity, s.inclusions, s.id) : null));
	const unit = Fight.makePlayer('p0', f.character, rail, dice, { pyrite: f.pyrite });
	const enemies = f.enemies.map((spec, i) => { const foe = Fight.makeDummy(`e${i}`, { dice: ['D4', 'D4'] }); foe.block = spec.block; foe.statuses = ints(spec.statuses); return foe; });
	const state = Fight.makeFight({ players: [unit], enemies, depth: f.depth });
	unit.hp = f.unit.hp;
	unit.block = f.unit.block;
	unit.block_lost = f.unit.block_lost;
	unit.statuses = ints(f.unit.statuses);
	unit.initial_resonance = f.unit.initial_resonance;
	unit.rerolls = f.unit.rerolls;
	unit.target = 'e0';
	const rng = makeRng(7);
	const snaps = [];
	for (const run of f.runs) {
		unit.hand = unit.dice.map((die, index) => {
			const spec = run.hand[index];
			const face = die.faces[spec.face];
			return { die_id: die.id, shape: die.shape, material: die.material || '', value: Dice.faceValue(face), face: spec.face, kind: face.kind || 'plain', top: Dice.top(die),
				held: spec.held, rerolls: spec.rerolls, locked: false, explosions: 0, phantom: false };
		});
		Fight.startRail(state, unit);
		const events = f.mode === 'dry' ? playDry(state, unit, rng) : Fight.runQueue(state, rng, true);
		snaps.push(snapshot(state, unit, events));
	}
	return { id: f.id, snaps };
}

// The forecast's way through a rail: every gem and the Birthstone resolved dry.
function playDry(state, unit, rng) {
	const events = [];
	while (state.queue.length) {
		const s = state.queue.shift();
		if (s.kind === 'gem') events.push(Fight.resolveGem(state, unit, s.socket, { dry: true, retrigger: Boolean(s.retrigger), scale: s.scale ?? 100 }, rng));
		else if (s.kind === 'birthstone') events.push(Fight.resolveBirthstone(state, unit, { dry: true, replay: Boolean(s.replay) }, rng));
		else events.push(Fight.perform(state, s, rng));
	}
	return events;
}

function snapshot(state, a, events) {
	const log = [];
	for (const e of events) {
		if (!e) continue;
		if (e.kind === 'gem_fire' || e.kind === 'gem_fizzle') log.push([e.kind, e.socket, e.resonance | 0]);
		else if (e.kind === 'birthstone') log.push(['birthstone', Boolean(e.fired), e.tiers.map((t) => Boolean(t.active))]);
	}
	const buffs = {};
	for (const [id, entry] of Object.entries(a.gem_buffs || {})) { const clean = ints(entry); if (Object.keys(clean).length) buffs[id] = clean; }
	return { unit: { hp: a.hp, max_hp: a.max_hp, block: a.block, resonance: a.resonance, gold: a.gold | 0, pyrite_delta: a.pyrite_delta | 0, pot: a.pot | 0, statuses: ints(a.statuses),
		granted_rerolls: a.granted_rerolls | 0, sparkle: a.sparkle | 0, quality_bonus: a.quality_bonus | 0, rank_buff: ints(a.rank_buff), gem_buffs: buffs,
		fired: a.fired_sockets.slice(), fizzled: a.fizzled_sockets.slice(), rail: a.rail.map((s) => (s ? String(s.id) : '')), hand: a.hand.map((r) => [r.die_id, r.value, Boolean(r.phantom)]),
		faces: a.dice.map((d) => d.faces.map((f) => f.value | 0)), amplify: Math.round(Number(a.amplify) * 10000) / 10000, cut_step_bonus: a.cut_step_bonus | 0,
		nullify_next: Boolean(a.nullify_next), repeat_next: a.repeat_next | 0, healed: a.healed | 0, dealt: a.dealt | 0, once: Object.keys(a.once).sort() },
	enemies: state.enemies.map((foe) => ({ hp: foe.hp, max_hp: foe.max_hp, block: foe.block, statuses: ints(foe.statuses), stolen_dice: foe.stolen_dice | 0, dread_turns: foe.dread_turns | 0 })),
	events: log };
}

// --- comparing -------------------------------------------------------------------------------

function differences(want, got, where = '', out = []) {
	if (out.length > 6) return out;
	if (typeof want !== typeof got || Array.isArray(want) !== Array.isArray(got)) { out.push(`${where}: godot ${JSON.stringify(want)} · js ${JSON.stringify(got)}`); return out; }
	if (want && typeof want === 'object') {
		const keys = new Set([...Object.keys(want), ...Object.keys(got)]);
		for (const key of keys) {
			if (!(key in want) || !(key in got)) { out.push(`${where}.${key}: godot ${JSON.stringify(want[key])} · js ${JSON.stringify(got[key])}`); continue; }
			differences(want[key], got[key], `${where}.${key}`, out);
		}
		return out;
	}
	if (want !== got) out.push(`${where}: godot ${JSON.stringify(want)} · js ${JSON.stringify(got)}`);
	return out;
}

function describe(f) {
	return `${f.mode} ${f.character} [${f.rail.map((s) => (s ? `${s.skill} ${s.carat}ct c${s.cut} k${s.clarity}${s.inclusions.length ? ' +' + s.inclusions.join('+') : ''}` : '·')).join(', ')}]`;
}

// Godot 4.7.2: GODOT_BIN, the path, or a console build beside the project, on the desktop or in
// downloads (the way music.mjs looks, without needing its encoder installed).
function findGodot() {
	const candidates = [process.env.GODOT_BIN];
	for (const name of ['godot', 'godot4']) {
		try { candidates.push(execFileSync(process.platform === 'win32' ? 'where' : 'which', [name], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).split(/\r?\n/)[0].trim()); } catch { /* not on the path */ }
	}
	const home = process.env.USERPROFILE || process.env.HOME || '';
	for (const dir of [path.dirname(ROOT), path.join(home, 'Desktop'), path.join(home, 'Downloads')]) {
		try { for (const file of readdirSync(dir)) if (/^Godot_v4\.7\.2-stable_win64_console\.exe$/i.test(file)) candidates.push(path.join(dir, file)); } catch { /* no such folder */ }
	}
	candidates.push('/Applications/Godot.app/Contents/MacOS/Godot');
	return candidates.find((c) => c && existsSync(c)) || null;
}

function runGodot(fixtureFile, outFile) {
	const godot = findGodot();
	if (!godot) throw new Error('Godot 4.7.2 was not found. Set GODOT_BIN to the console executable.');
	return new Promise((resolve, reject) => {
		const child = spawn(godot, ['--headless', '--path', ROOT, '--script', 'res://tools/balance_parity.gd', '--', fixtureFile, outFile], { cwd: ROOT, windowsHide: true });
		let log = '';
		child.stdout.on('data', (d) => { log += d; });
		child.stderr.on('data', (d) => { log += d; });
		child.on('error', reject);
		child.on('close', (code) => {
			const errors = log.split(/\r?\n/).filter((l) => /SCRIPT ERROR|^ERROR:/.test(l));
			if (code !== 0 || errors.length) reject(new Error(errors.join('\n') || `Godot exited with ${code}\n${log.slice(-1200)}`));
			else resolve(log);
		});
	});
}

await mkdir(OUT, { recursive: true });
const list = fixtures(COUNT, SEED);
const fixtureFile = path.join(OUT, 'fixtures.json');
const godotFile = path.join(OUT, 'godot.json');
await writeFile(fixtureFile, JSON.stringify(list));
const started = Date.now();
await runGodot(fixtureFile, godotFile);
const godot = JSON.parse(await readFile(godotFile, 'utf8'));
console.log(`Godot played ${godot.length} fixtures in ${((Date.now() - started) / 1000).toFixed(1)}s`);
let failed = 0;
for (const f of list) {
	const want = godot.find((g) => g.id === f.id);
	let got;
	try { got = play(f); } catch (error) { failed += 1; console.log(`\n#${f.id} ${describe(f)}\n  JS threw: ${error.stack || error}`); continue; }
	const diff = differences(want.snaps, got.snaps, 'rail');
	if (diff.length) {
		failed += 1;
		if (failed <= 25) console.log(`\n#${f.id} ${describe(f)}\n  ${diff.join('\n  ')}`);
	}
}
console.log(`\n${list.length - failed} of ${list.length} fixtures agree (${list.filter((f) => f.mode === 'live').length} live, ${list.filter((f) => f.mode === 'dry').length} dry).`);
if (!args.includes('--keep')) await rm(OUT, { recursive: true, force: true });
process.exit(failed ? 1 : 0);
