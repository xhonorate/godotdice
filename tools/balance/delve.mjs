// The balance runs: whole runs played through the real rules by a bot (tools/balance/bot.gd),
// every Birthstone of every delver down every mine, and what the runs say about the stones,
// the gems and the creatures (tools/balance/analyze.mjs). docs/BALANCE.md says how to read it.
//
//   node tools/balance/delve.mjs run [name] [--seeds 40] [--mines QUARRY,SEEPS] [--delvers ARDOR,RUE]
//        [--stones first|all|RAMPART,RENOWN] [--kit auto|lean|standard|rich|peak|0..7] [--hazard N]
//        [--workers N] [--seed 1] [--plant SKILL] [--carat N] [--cut N] [--clarity N] [--sockets N]
//        [--vault N] [--opal-pct N] [--plant-pct N] [--rift-wardens N] [--pack <file>] [--trace]
//        [--gem-seeds N]
//   node tools/balance/delve.mjs gems [name] [--seeds 120]
//   node tools/balance/delve.mjs report [name]
//   node tools/balance/delve.mjs fights [name] [--foe THE_REGENT] [--lost] [--limit 5]
//   node tools/balance/delve.mjs diff <before> <after>
//   node tools/balance/delve.mjs calibrate [--seeds 5] [--target 40]
//   node tools/balance/delve.mjs list
//
// `run` plays `seeds` runs for every delver, stone and mine asked for, on every core, into
// build/balance/delve/<name>/ (runs.jsonl, one run a line; meta.json; summary.json; report.md;
// report.html), then prints the report. `name` is "latest" when left out, and a run of the same
// name is kept beside it as <name>.prev, which `report` sets it against.
//
// A delver's stones go down the same shafts with the same vault to choose a rail from (the
// seed and the delver fix both), so one stone is read against another on the same luck.
//
// A gem is read by the runs it was planted in, and a delver's three stones are planted the same
// one, so a run of 40 seeds reads a rare gem off a dozen kits. `gems` adds a pass for them to a
// run already played (and `--gem-seeds` to one about to be): the first stones only, on seeds
// of their own, every run a different kit. Those runs count for the gems and for nothing else.
//
// `fights` prints fights turn by turn from a run played with --trace (the hand the bot locked,
// what each gem did, what each creature threw): the way to see why a creature the report marks
// does what it does. --foe keeps the fights a creature stood in, --lost the ones the bot lost.
//
// --kit says how well stocked the vault is, a rung of KITS: the carats, Cut and Clarity of
// every stone in it, read off the mine's own carat band. `auto` (what a run uses when a
// calibration has been made) gives each mine the rung `calibrate` found for it: the lowest
// one at which the bot's first stones beat the mine's boss `target` percent of the time, so
// every mine is played where it is neither a walk nor a wall. A mine nobody beats at the top
// rung is played there, and says so. --carat, --cut, --clarity, --sockets and --vault set one
// number by hand. --plant sets one skill on every rail (a what-if on one gem); --pack plays a
// changed copy of the content pack.

import { spawn, execFileSync } from 'node:child_process';
import { createWriteStream, existsSync, readdirSync } from 'node:fs';
import { mkdir, readFile, writeFile, rm, rename, readdir } from 'node:fs/promises';
import { availableParallelism } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { analyze, render, diff } from './analyze.mjs';
import { page } from './page.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '../..');
const OUT = path.join(process.env.DEEP_BALANCE_DIR ? path.resolve(process.env.DEEP_BALANCE_DIR) : path.join(ROOT, 'build/balance'), 'delve');
// How well stocked a vault is, rung by rung: `carat` over the mine's soft cap (`soft`) or its
// cap (`cap`), never past the heaviest a stone can be; Cut 0 Poor to 4 Perfect; Clarity 3
// Clear, 4 Pristine, 5 Flawless.
const KITS = [
	{ name: 'lean', from: 'soft', carat: -1, cut: 2, clarity: 3 },
	{ name: 'standard', from: 'soft', carat: 0, cut: 3, clarity: 3 },
	{ name: 'rich', from: 'cap', carat: 0, cut: 4, clarity: 3 },
	{ name: 'rich+2', from: 'cap', carat: 2, cut: 4, clarity: 4 },
	{ name: 'rich+4', from: 'cap', carat: 4, cut: 4, clarity: 4 },
	{ name: 'rich+6', from: 'cap', carat: 6, cut: 4, clarity: 5 },
	{ name: 'rich+8', from: 'cap', carat: 8, cut: 4, clarity: 5 },
	{ name: 'peak', from: 'cap', carat: 99, cut: 4, clarity: 5 },
];
const KIT_FILE = path.join(OUT, 'kits.json');
// The gems' own pass: its runs' names begin with this (analyze.mjs reads them apart), and its
// seeds start this far past the run's.
const GEM_TAG = 'g.';
const GEM_SEEDS_FROM = 100000;

const args = process.argv.slice(2);
const valued = new Set(['seeds', 'mines', 'delvers', 'stones', 'kit', 'hazard', 'workers', 'seed', 'plant', 'carat', 'cut', 'clarity', 'sockets', 'vault', 'opal-pct', 'plant-pct', 'rift-wardens', 'pack', 'target', 'gem-seeds', 'foe', 'limit']);
const option = (name) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : undefined; };
const number = (name, fallback) => (option(name) === undefined ? fallback : Number(option(name)));
const flag = (name) => args.includes(`--${name}`);
const words = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && valued.has(args[i - 1].replace(/^--/, ''))));
const command = words[0] || 'report';
const name = words[1] || 'latest';

const packFile = option('pack') ? path.resolve(option('pack')) : path.join(ROOT, 'content/deep_cut.json');
const pack = JSON.parse(await readFile(packFile, 'utf8'));
const dirOf = (run) => path.join(OUT, run);
const delverOrder = Object.keys(pack.characters).sort((a, b) => Number(pack.characters[a].unlock_order ?? 0) - Number(pack.characters[b].unlock_order ?? 0));
const mineOrder = Object.keys(pack.mines).sort((a, b) => Number(pack.mines[a].tier ?? 0) - Number(pack.mines[b].tier ?? 0));
const CARAT_MAX = Number((pack.constants || {}).carat_max ?? 24);

function packHash(p) {
	const text = JSON.stringify(p);
	let h = 0x811c9dc5;
	for (let i = 0; i < text.length; i++) { h ^= text.charCodeAt(i); h = Math.imul(h, 0x01000193); }
	return (h >>> 0).toString(16).padStart(8, '0');
}

// Godot 4.7.2: GODOT_BIN, the path, or a build beside the project, on the desktop or in downloads.
function findGodot() {
	const candidates = [process.env.GODOT_BIN];
	for (const exe of ['godot', 'godot4']) {
		try { candidates.push(execFileSync(process.platform === 'win32' ? 'where' : 'which', [exe], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).split(/\r?\n/)[0].trim()); } catch { /* not on the path */ }
	}
	const home = process.env.USERPROFILE || process.env.HOME || '';
	for (const dir of [path.dirname(ROOT), path.join(home, 'Desktop'), path.join(home, 'Downloads')]) {
		try { for (const file of readdirSync(dir).sort((a, b) => Number(/_console/i.test(b)) - Number(/_console/i.test(a)))) if (/^Godot_v4\.7\.2-stable_win64(_console)?\.exe$/i.test(file)) candidates.push(path.join(dir, file)); } catch { /* no such folder */ }
	}
	candidates.push('/Applications/Godot.app/Contents/MacOS/Godot');
	return candidates.find((c) => c && existsSync(c)) || null;
}

// --- kits ----------------------------------------------------------------------------------------

function kitAt(mine, rung) {
	const kit = KITS[Math.max(0, Math.min(KITS.length - 1, rung))];
	const band = pack.mines[mine].carat || { soft: 5, cap: 7 };
	return { rung: KITS.indexOf(kit), name: kit.name, carat: Math.max(1, Math.min(CARAT_MAX, Number(band[kit.from]) + kit.carat)), cut: kit.cut, clarity: kit.clarity };
}

async function calibration() {
	try { return JSON.parse(await readFile(KIT_FILE, 'utf8')); } catch { return null; }
}

// The rung each mine is played at: what --kit names, or what the calibration found.
async function rungs(mines) {
	const asked = String(option('kit') || 'auto').toLowerCase();
	const out = {};
	if (asked === 'auto') {
		const found = await calibration();
		if (!found) console.log('no calibration yet (node tools/balance/delve.mjs calibrate): every mine is played with a standard kit');
		else if (found.packHash !== packHash(pack)) console.log('the calibration was made on another pack: it is used as it is (node tools/balance/delve.mjs calibrate makes it again)');
		for (const mine of mines) out[mine] = found && found.rungs && Number.isInteger(found.rungs[mine]) ? found.rungs[mine] : 1;
		return out;
	}
	const at = /^\d+$/.test(asked) ? Number(asked) : KITS.findIndex((k) => k.name === asked);
	if (at < 0 || at >= KITS.length) { console.error(`No kit called ${asked}. There are: auto, ${KITS.map((k, i) => `${k.name} (${i})`).join(', ')}`); process.exit(2); }
	for (const mine of mines) out[mine] = at;
	return out;
}

// --- the jobs ------------------------------------------------------------------------------------

function pick(list, wanted, what) {
	if (!wanted) return list;
	const asked = wanted.split(',').map((w) => w.trim().toUpperCase()).filter(Boolean);
	for (const key of asked) if (!list.includes(key)) { console.error(`No ${what} called ${key}. There are: ${list.join(', ')}`); process.exit(2); }
	return list.filter((key) => asked.includes(key));
}

function jobsFor(kits, { stones = String(option('stones') || 'all'), seeds = Math.max(1, number('seeds', 40) | 0), tag = '', from = 0 } = {}) {
	const useDelvers = pick(delverOrder, option('delvers'), 'delver');
	const useMines = pick(mineOrder, option('mines'), 'mine').filter((mine) => kits[mine] !== undefined);
	const seed0 = (number('seed', 1) | 0) + from;
	const jobs = [];
	for (const mine of useMines) {
		const kit = kitAt(mine, kits[mine]);
		for (const delver of useDelvers) {
			const keys = ['', ...(pack.characters[delver].variants || []).map((v) => String(v.key))];
			const worn = stones === 'all' ? keys : stones === 'first' ? [''] : keys.filter((k) => k !== '' && stones.toUpperCase().split(',').includes(k));
			for (const stone of worn) {
				for (let i = 0; i < seeds; i++) {
					const job = { id: `${tag}${delver}.${stone || 'first'}.${mine}.${seed0 + i}`, character: delver, birthstone: stone, mine, seed: seed0 + i, hazard: number('hazard', 0) | 0,
						carat: option('carat') !== undefined ? number('carat') | 0 : kit.carat, cut: option('cut') !== undefined ? number('cut') | 0 : kit.cut,
						clarity: option('clarity') !== undefined ? number('clarity') | 0 : kit.clarity, rung: kit.rung };
					for (const [key, opt] of [['sockets', 'sockets'], ['vault', 'vault'], ['opal_pct', 'opal-pct'], ['plant_pct', 'plant-pct'], ['rift_wardens', 'rift-wardens']]) if (option(opt) !== undefined) job[key] = number(opt);
					if (option('plant')) job.plant = String(option('plant')).toUpperCase();
					if (flag('trace')) job.trace = true;
					jobs.push(job);
				}
			}
		}
	}
	return jobs;
}

// --- playing them -------------------------------------------------------------------------------

async function countLines(file) {
	try { return (await readFile(file, 'utf8')).split('\n').filter(Boolean).length; } catch { return 0; }
}

async function play(jobs, dir, file = 'runs.jsonl') {
	const godot = findGodot();
	if (!godot) { console.error('Godot 4.7.2 was not found. Set GODOT_BIN to the Godot executable.'); process.exit(2); }
	const tmp = path.join(dir, 'tmp');
	await rm(tmp, { recursive: true, force: true });
	await mkdir(tmp, { recursive: true });
	const count = Math.max(1, Math.min(jobs.length, number('workers', Math.max(1, availableParallelism() - 2)) | 0));
	// Dealt round like cards, so every worker gets its share of the long mines and the short.
	const slices = Array.from({ length: count }, () => []);
	jobs.forEach((job, i) => slices[i % count].push(job));
	const started = Date.now();
	const outs = [];
	const failures = [];
	const done = slices.map((slice, i) => new Promise((resolve) => {
		const jobsFile = path.join(tmp, `jobs${i}.json`);
		const outFile = path.join(tmp, `runs${i}.jsonl`);
		outs.push(outFile);
		writeFile(jobsFile, JSON.stringify({ jobs: slice })).then(() => {
			const extra = option('pack') ? [`pack=${packFile}`] : [];
			const child = spawn(godot, ['--headless', '--path', ROOT, '--script', 'res://tools/balance/delve.gd', '--', `jobs=${jobsFile}`, `out=${outFile}`, ...extra], { cwd: ROOT, windowsHide: true });
			let log = '';
			const keep = (d) => { log += d; if (log.length > 200000) log = log.slice(-100000); };
			child.stdout.on('data', keep);
			child.stderr.on('data', keep);
			child.on('error', (e) => { failures.push(String(e)); resolve(); });
			child.on('close', () => {
				for (const line of log.split(/\r?\n/)) if (/SCRIPT ERROR|^ERROR:|^!! /.test(line)) failures.push(line.trim());
				resolve();
			});
		});
	}));
	const show = process.stdout.isTTY;
	const tick = setInterval(async () => {
		let lines = 0;
		for (const file of outs) lines += await countLines(file);
		const seconds = (Date.now() - started) / 1000;
		const rate = lines / Math.max(1, seconds);
		const left = rate > 0 ? (jobs.length - lines) / rate : 0;
		if (show) process.stdout.write(`\r${lines}/${jobs.length} runs · ${seconds.toFixed(0)}s · ${rate.toFixed(1)} a second${lines ? ` · about ${Math.ceil(left / 60)} min left` : ''}   `);
	}, 2000);
	await Promise.all(done);
	clearInterval(tick);
	if (show) process.stdout.write('\n');
	// One file, in the jobs' own order.
	const byId = new Map();
	for (const file of outs) {
		let text = '';
		try { text = await readFile(file, 'utf8'); } catch { continue; }
		for (const line of text.split('\n')) {
			if (!line.trim()) continue;
			try { const row = JSON.parse(line); byId.set(row.id, line); } catch { failures.push(`unreadable line in ${path.basename(file)}`); }
		}
	}
	const merged = createWriteStream(path.join(dir, file));
	let written = 0;
	for (const job of jobs) if (byId.has(job.id)) { merged.write(byId.get(job.id) + '\n'); written += 1; }
	await new Promise((resolve) => merged.end(resolve));
	await rm(tmp, { recursive: true, force: true });
	const unique = [...new Set(failures)];
	if (unique.length) {
		console.log(`${unique.length} thing${unique.length === 1 ? '' : 's'} went wrong:`);
		for (const line of unique.slice(0, 12)) console.log(`  ${line}`);
	}
	if (written < jobs.length) console.log(`${jobs.length - written} runs never finished (a worker stopped early).`);
	return { seconds: Math.round((Date.now() - started) / 1000), written, workers: count, failures: unique.slice(0, 50) };
}

async function readRuns(dir, file = 'runs.jsonl') {
	const rows = [];
	let text = '';
	try { text = await readFile(path.join(dir, file), 'utf8'); } catch { return rows; }
	for (const line of text.split('\n')) if (line.trim()) rows.push(JSON.parse(line));
	return rows;
}

async function loadSummary(run) {
	try { return JSON.parse(await readFile(path.join(dirOf(run), 'summary.json'), 'utf8')); } catch { return null; }
}

async function report(run, quiet = false) {
	const dir = dirOf(run);
	const rows = await readRuns(dir);
	if (!rows.length) { console.error(`No runs in ${path.relative(process.cwd(), dir)}. Play some: node tools/balance/delve.mjs run ${run}`); process.exit(1); }
	let meta = {};
	try { meta = JSON.parse(await readFile(path.join(dir, 'meta.json'), 'utf8')); } catch { /* an older run */ }
	const summary = analyze(rows, pack, { meta });
	await writeFile(path.join(dir, 'summary.json'), JSON.stringify(summary));
	const before = await loadSummary(`${run}.prev`);
	const moved = before ? diff(before, summary) : null;
	const text = render(summary, moved);
	await writeFile(path.join(dir, 'report.md'), text);
	// The page twice: whole, to open from disk, and without its wrapper, as a claude.ai artifact wants it.
	await writeFile(path.join(dir, 'report.html'), page(summary, moved, { standalone: true }));
	await writeFile(path.join(dir, 'report.page.html'), page(summary, moved));
	if (!quiet) {
		console.log(text);
		console.log(`\nkept in ${path.relative(process.cwd(), dir)} (runs.jsonl, summary.json, report.md, report.html)`);
	}
	return summary;
}

// --- commands --------------------------------------------------------------------------------------

if (command === 'run') {
	const kits = await rungs(mineOrder);
	const gemSeeds = Math.max(0, number('gem-seeds', 0) | 0);
	const main = jobsFor(kits);
	const jobs = gemSeeds ? [...main, ...jobsFor(kits, { stones: 'first', seeds: gemSeeds, tag: GEM_TAG, from: GEM_SEEDS_FROM })] : main;
	const dir = dirOf(name);
	if (existsSync(path.join(dir, 'runs.jsonl'))) {
		const prev = dirOf(`${name}.prev`);
		await rm(prev, { recursive: true, force: true });
		await rename(dir, prev);
	}
	await mkdir(dir, { recursive: true });
	const mines = [...new Set(jobs.map((j) => j.mine))];
	console.log(`${main.length} runs: ${[...new Set(jobs.map((j) => j.character))].length} delvers · ${[...new Set(main.map((j) => `${j.character}/${j.birthstone}`))].length} Birthstones · ${mines.length} mines · ${Math.max(1, number('seeds', 40) | 0)} seeds each${gemSeeds ? `, and ${jobs.length - main.length} more for the gems (${gemSeeds} seeds, first stones)` : ''}`);
	console.log(`kits: ${mines.map((m) => `${pack.mines[m].name || m} ${kitAt(m, kits[m]).name}`).join(' · ')}`);
	const played = await play(jobs, dir);
	await writeFile(path.join(dir, 'meta.json'), JSON.stringify({ name, created: new Date().toISOString(), packHash: packHash(pack), pack: option('pack') ? packFile : '', args: args.slice(1), jobs: jobs.length,
		kits: Object.fromEntries(mines.map((m) => [m, kitAt(m, kits[m])])), ...played }, null, '\t'));
	await report(name);
} else if (command === 'gems') {
	// A finer reading of the gems, added to a run already played: its kits, its pack, the first
	// stones only, seeds of their own. Played again, it takes the place of the pass before it.
	const dir = dirOf(name);
	let meta = null;
	try { meta = JSON.parse(await readFile(path.join(dir, 'meta.json'), 'utf8')); } catch { /* no such run */ }
	if (!meta || !meta.kits) { console.error(`No run called ${name} to add to. Play one: node tools/balance/delve.mjs run ${name}`); process.exit(1); }
	if (meta.packHash !== packHash(pack)) console.log(`${name} was played on another pack (${meta.packHash}): the gems' pass is played on this one (${packHash(pack)})`);
	const seeds = Math.max(1, number('seeds', 120) | 0);
	const jobs = jobsFor(Object.fromEntries(Object.entries(meta.kits).map(([mine, kit]) => [mine, kit.rung])), { stones: 'first', seeds, tag: GEM_TAG, from: GEM_SEEDS_FROM });
	console.log(`${jobs.length} runs for the gems, added to ${name}: ${[...new Set(jobs.map((j) => j.character))].length} delvers' first stones · ${[...new Set(jobs.map((j) => j.mine))].length} mines · ${seeds} seeds each`);
	const played = await play(jobs, dir, 'gems.jsonl');
	const kept = (await readRuns(dir)).filter((row) => !String(row.id).startsWith(GEM_TAG));
	const added = await readRuns(dir, 'gems.jsonl');
	await writeFile(path.join(dir, 'runs.jsonl'), [...kept, ...added].map((row) => JSON.stringify(row)).join('\n') + '\n');
	await rm(path.join(dir, 'gems.jsonl'), { force: true });
	await writeFile(path.join(dir, 'meta.json'), JSON.stringify({ ...meta, gems: { created: new Date().toISOString(), seeds, jobs: jobs.length, ...played } }, null, '\t'));
	await report(name);
} else if (command === 'fights') {
	const rows = await readRuns(dirOf(name));
	const foe = option('foe') ? String(option('foe')).toUpperCase() : '';
	const limit = Math.max(1, number('limit', 5) | 0);
	let shown = 0;
	let traced = false;
	for (const row of rows) {
		for (const fight of row.fights || []) {
			if (!fight.log) continue;
			traced = true;
			if ((foe && !fight.foes.includes(foe)) || (flag('lost') && fight.won) || shown >= limit) continue;
			shown += 1;
			console.log(`\n${row.id} · depth ${fight.d} ${fight.k} · ${fight.foes.map((key) => (pack.creatures[key] || {}).name || key).join(', ')} · ${fight.won ? 'won' : `lost to ${fight.killer || '?'}`} in ${fight.turns} turns · health ${fight.hp0} to ${fight.hp1} of ${fight.max}`);
			console.log(`  rail: ${fight.rail.map((key) => (pack.skills[key] || {}).name || key).join(', ')}`);
			for (const turn of fight.log) {
				console.log(`  turn ${turn.turn}: health ${turn.hp}, block ${turn.block}, hand ${turn.hand.join(' ')}, rerolls left ${turn.rerolls_left}, threw ${turn.thrown} at ${turn.foes.join('; ')}`);
				console.log(`    ${turn.did.join(' · ')}`);
			}
		}
	}
	if (!traced) console.log(`${name} keeps no fights turn by turn. Play some that do: node tools/balance/delve.mjs run look --mines QUARRY --seeds 4 --trace`);
	else if (!shown) console.log('No fight like that in this run.');
} else if (command === 'report') {
	await report(name);
} else if (command === 'diff') {
	const [a, b] = [words[1], words[2]];
	const before = a && await loadSummary(a);
	const after = b && await loadSummary(b);
	if (!before || !after) { console.error('diff wants two runs that have been reported: node tools/balance/delve.mjs diff <before> <after>'); process.exit(2); }
	console.log(render(after, diff(before, after)));
} else if (command === 'calibrate') {
	// Every mine at every rung, the first stones only: the lowest rung where the bot beats the
	// boss often enough is the one the mine is played at from now on.
	const target = number('target', 40) / 100;
	const seeds = Math.max(2, number('seeds', 5) | 0);
	const dir = dirOf('calibrate');
	await rm(dir, { recursive: true, force: true });
	await mkdir(dir, { recursive: true });
	const mines = pick(mineOrder, option('mines'), 'mine');
	const jobs = [];
	for (let rung = 1; rung < KITS.length; rung++) jobs.push(...jobsFor(Object.fromEntries(mines.map((m) => [m, rung])), { stones: 'first', seeds, tag: `r${rung}.` }));
	console.log(`calibrating: ${mines.length} mines × ${KITS.length - 1} kits × ${delverOrder.length} delvers × ${seeds} seeds = ${jobs.length} runs`);
	const played = await play(jobs, dir);
	const rows = await readRuns(dir);
	const jobById = new Map(jobs.map((j) => [j.id, j]));
	const table = {};
	const found = {};
	for (const mine of mines) {
		table[mine] = [];
		for (let rung = 1; rung < KITS.length; rung++) {
			const of = rows.filter((r) => r.mine === mine && (jobById.get(r.id) || {}).rung === rung && (r.outcome === 'conquered' || r.outcome === 'fallen'));
			const clear = of.length ? of.filter((r) => r.outcome === 'conquered').length / of.length : 0;
			const progress = of.length ? of.reduce((s, r) => s + r.progress, 0) / of.length : 0;
			table[mine].push({ rung, kit: kitAt(mine, rung), runs: of.length, clear: Math.round(clear * 1000) / 1000, progress: Math.round(progress * 1000) / 1000 });
		}
		const first = table[mine].find((t) => t.clear >= target);
		found[mine] = first ? first.rung : KITS.length - 1;
	}
	const saved = await calibration();
	const kept = { created: new Date().toISOString(), packHash: packHash(pack), target, seeds, seconds: played.seconds, rungs: { ...((saved && saved.rungs) || {}), ...found }, table: { ...((saved && saved.table) || {}), ...table } };
	await mkdir(OUT, { recursive: true });
	await writeFile(KIT_FILE, JSON.stringify(kept, null, '\t'));
	console.log(`\nbeaten by the bot's first stones, kit by kit (the one each mine is played at from now on is marked; target ${Math.round(target * 100)}%)\n`);
	console.log(`${'mine'.padEnd(16)}${KITS.slice(1).map((k) => k.name.padStart(10)).join('')}`);
	for (const mine of mines) {
		console.log(`${(pack.mines[mine].name || mine).padEnd(16)}${table[mine].map((t) => `${t.rung === found[mine] ? '>' : ' '}${Math.round(t.clear * 100)}%`.padStart(10)).join('')}`);
		console.log(`${''.padEnd(16)}${table[mine].map((t) => `${t.kit.carat}ct`.padStart(10)).join('')}`);
	}
	console.log(`\nkept in ${path.relative(process.cwd(), KIT_FILE)} · ${played.seconds}s`);
} else if (command === 'list') {
	let runs = [];
	try { runs = (await readdir(OUT, { withFileTypes: true })).filter((d) => d.isDirectory()).map((d) => d.name); } catch { /* none yet */ }
	for (const run of runs.sort()) {
		let meta = null;
		try { meta = JSON.parse(await readFile(path.join(dirOf(run), 'meta.json'), 'utf8')); } catch { /* unfinished */ }
		console.log(`${run.padEnd(24)} ${meta ? `${String(meta.written).padStart(6)} runs · ${new Date(meta.created).toLocaleString()} · pack ${meta.packHash} · ${meta.args.join(' ')}` : '(no meta)'}`);
	}
	if (!runs.length) console.log('No runs yet. Play some: node tools/balance/delve.mjs run');
} else {
	console.error(`No command called ${command}. Try: run, gems, report, fights, diff, calibrate, list`);
	process.exit(2);
}
