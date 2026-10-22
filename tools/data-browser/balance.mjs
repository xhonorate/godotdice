// Run balance sweeps from the command line, on every core, into build/balance/ where the
// Balance page reads them (the previous run kept beside each as <sweep>.prev.json).
//
//   node tools/data-browser/balance.mjs [gems|cutclarity|inclusions|pairs|rails|carats|hunt|growth|all]
//        [--workers N] [--turns N] [--samples N] [--carat N] [--seed N] [--hosts N]
//        [--bands QUARRY,FURNACE,RIFT@57] [--fights N]
//
//   node tools/data-browser/balance.mjs check [--limit X] [--rerun] [--quick]
//
// The hunt also takes --copies N (the most of one gem a rail may hold), --opals N (the most
// opals) and --apart (no opal reaches another: a rule tried in the sim, not the game's).
// --gem-plays N lets no gem play more than N times a turn (also a rule tried only in the sim).
// --pack <file> plays a changed copy of the content pack instead of content/deep_cut.json.
//
// The pairs, rails, carats, hunt and growth sweeps read which gem a rail's rerolls chase from
// the gems sweep, so they run it first when it is missing or the pack has moved on.
//
// `check` is the balance gate: it reads the hunt (running it when it is missing, was played on
// another pack, or --rerun asks; --quick plays a lighter one) and, for every band it hunted,
// sets the strongest rail it found on each bowl against that bowl's plain rail (its best gems
// alone) in the boss fight. A band whose strongest rail beats the plain rail by more than
// --limit times (default LIMIT) is reported, and so is anything that moved since the run
// before. Exits 1 when a band is over the limit.

import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads';
import { readFile } from 'node:fs/promises';
import { availableParallelism } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as C from './js/sim/content.js';
import * as Balance from './js/sim/balance.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const LIMIT = 4;

if (!isMainThread) {
	C.setPack(workerData.pack);
	parentPort.on('message', ({ id, task }) => parentPort.postMessage({ id, result: Balance.runTask(task) }));
} else {
	const Store = await import('./balance-store.mjs');
	const args = process.argv.slice(2);
	const option = (name) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : undefined; };
	const number = (name) => (option(name) === undefined ? undefined : Number(option(name)));
	const flag = (name) => args.includes(`--${name}`);
	const valued = new Set(['workers', 'turns', 'samples', 'carat', 'seed', 'hosts', 'bands', 'fights', 'limit', 'copies', 'opals', 'pack', 'gem-plays']);
	const words = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && valued.has(args[i - 1].replace(/^--/, ''))));
	const wanted = words[0] || 'all';
	const checking = wanted === 'check';
	const sweeps = checking ? [] : wanted === 'all' ? Balance.SWEEPS : [wanted];
	for (const sweep of sweeps) if (!Balance.SWEEPS.includes(sweep)) { console.error(`No sweep called ${sweep}. Try one of: ${Balance.SWEEPS.join(', ')}, all, check`); process.exit(2); }
	const pack = JSON.parse(await readFile(option('pack') ? path.resolve(option('pack')) : path.resolve(here, '../../content/deep_cut.json'), 'utf8'));
	C.setPack(pack);
	const settings = { ...Balance.DEFAULTS, samples: { ...Balance.DEFAULTS.samples } };
	for (const key of ['turns', 'carat', 'seed', 'hosts']) if (number(key) !== undefined) settings[key] = number(key);
	if (number('samples') !== undefined) for (const sweep of Balance.SWEEPS) settings.samples[sweep] = number('samples');
	if (option('bands')) settings.huntBands = option('bands').split(',').map((b) => b.trim()).filter(Boolean);
	if (number('fights') !== undefined) settings.runFights = number('fights');
	if (number('copies') !== undefined) settings.copies = number('copies');
	if (number('opals') !== undefined) settings.opals = number('opals');
	if (flag('apart')) settings.opalsApart = true;
	if (number('gem-plays') !== undefined) settings.gemPlays = number('gem-plays');
	if (checking && flag('quick')) Object.assign(settings, { huntStarts: 2, huntPasses: 1, huntVerify: 150, samples: { ...settings.samples, hunt: 10 } });
	const count = Math.max(1, number('workers') ?? Math.max(1, availableParallelism() - 1));
	const workers = Array.from({ length: count }, () => new Worker(fileURLToPath(import.meta.url), { workerData: { pack } }));
	const hash = Balance.packHash(pack);

	// Play one round of tasks on the pool.
	const playRound = (tasks, report) => new Promise((resolve, reject) => {
		const results = new Array(tasks.length);
		let next = 0, done = 0;
		if (!tasks.length) { resolve(results); return; }
		const feed = (worker) => { if (next < tasks.length) { const id = next++; worker.postMessage({ id, task: tasks[id] }); } };
		for (const worker of workers) {
			worker.removeAllListeners('message');
			worker.removeAllListeners('error');
			worker.on('error', reject);
			worker.on('message', ({ id, result }) => {
				results[id] = result;
				done += 1;
				report(done);
				if (done === tasks.length) resolve(results); else feed(worker);
			});
			feed(worker);
		}
	});

	const run = async (sweep, context, played = settings) => {
		const job = Balance.startJob(sweep, played, context);
		const started = Date.now();
		let finished = 0;
		for (let tasks = Balance.nextTasks(job); tasks; tasks = Balance.nextTasks(job)) {
			const total = finished + Math.max(tasks.length, Balance.estimateTasks(job));
			const results = await playRound(tasks, (done) => {
				const seconds = (Date.now() - started) / 1000;
				const label = sweep === 'hunt' ? `round ${job.round + 1}${job.phase === 'verify' ? ' (checking what it found)' : ''} · ` : '';
				process.stdout.write(`\r${sweep}: ${label}${finished + done}/${Math.max(total, finished + done)} tasks · ${seconds.toFixed(0)}s   `);
			});
			finished += tasks.length;
			Balance.takeResults(job, results);
		}
		process.stdout.write('\n');
		const seconds = Math.round((Date.now() - started) / 1000);
		return Balance.finishJob(job, { packHash: hash, created: new Date().toISOString(), seconds, leads: context.leads });
	};

	let gems = await Store.load('gems');
	const freshGems = async () => {
		if (!gems || gems.packHash !== hash || (gems.vector || []).length !== Balance.VECTOR.length) {
			console.log('reading the gems sweep first: running it');
			gems = await run('gems', {}, { ...settings, samples: { ...Balance.DEFAULTS.samples } });
			await Store.save('gems', gems);
		}
		return gems;
	};
	const contextFor = async (sweep) => (['pairs', 'rails', 'carats', 'hunt', 'growth'].includes(sweep) ? { leads: Balance.leadsFrom(await freshGems()) } : {});

	for (const sweep of sweeps) {
		const result = await run(sweep, await contextFor(sweep));
		await Store.save(sweep, result);
		if (sweep === 'gems') gems = result;
		console.log(`${sweep}: saved to ${path.relative(process.cwd(), path.join(Store.DIR, `${sweep}.json`))} · ${result.seconds}s`);
	}

	let exit = 0;
	if (checking) {
		let hunt = await Store.load('hunt');
		const stale = !hunt || hunt.packHash !== hash;
		if (stale || flag('rerun')) {
			console.log(stale ? (hunt ? 'the hunt was played on another pack: hunting again' : 'no hunt yet: hunting') : 'hunting again');
			hunt = await run('hunt', await contextFor('hunt'));
			await Store.save('hunt', hunt);
		}
		const prev = await Store.load('hunt', true);
		exit = report(hunt, prev, Number(option('limit') ?? LIMIT));
	}
	await Promise.all(workers.map((w) => w.terminate()));
	process.exit(exit);
}

// --- the gate's report ---------------------------------------------------------------------------

function report(hunt, prev, limit) {
	const w = { ...Balance.DEFAULT_WEIGHTS, ...(hunt.weights || {}), fight: 'boss' };
	const T = Math.max(1, hunt.settings.turns);
	const name = (k) => C.skill(k).name || k;
	const fmt = (v, d = 1) => (Number.isFinite(v) ? v.toLocaleString('en-GB', { maximumFractionDigits: v >= 100 ? 0 : d }) : '—');
	const turns = (v) => (!Number.isFinite(v) ? 'never' : v < 0.1 ? 'under 0.1' : fmt(v));
	const bandLines = (result) => {
		const out = {};
		for (const band of result.bands || []) {
			let worst = null;
			for (const bowl of result.bowls) {
				const r = Balance.huntReport(result, bowl, band.key, w);
				if (!r || !r.builds.length || !r.plain) continue;
				const top = r.builds[0];
				const ratio = top.value / Math.max(1e-9, r.plain.value);
				const line = { bowl, band, top, plain: r.plain, ratio, randomTurns: r.randomTurns };
				if (!worst || ratio > worst.ratio) worst = line;
			}
			if (worst) out[band.key] = worst;
		}
		return out;
	};
	const now = bandLines(hunt);
	const before = prev && JSON.stringify(prev.settings) === JSON.stringify(hunt.settings) ? bandLines(prev) : null;
	console.log(`\nThe balance gate · boss fight · the strongest rail the hunt found on any bowl, against that bowl's best gems alone (limit ${limit}x)`);
	console.log(`hunt of ${new Date(hunt.created).toLocaleString()} · ${hunt.rounds} rounds · ${hunt.seconds}s\n`);
	let over = 0;
	for (const [key, x] of Object.entries(now)) {
		const flagged = x.ratio > limit;
		if (flagged) over += 1;
		const was = before && before[key];
		const moved = was ? ` (was ${fmt(was.ratio)}x${was.top.key !== x.top.key ? `, with ${was.top.rail.map(name).join(', ')}` : ''})` : '';
		console.log(`${flagged ? 'OVER ' : '     '}${x.band.name.padEnd(26)} carat ${String(x.band.carat).padStart(2)} · ${fmt(x.ratio)}x the plain rail${moved}`);
		console.log(`       ${(C.character(x.bowl).name || x.bowl).padEnd(8)} ${x.top.rail.map(name).join(', ')}`);
		console.log(`       kills ${x.band.bossName} (${fmt(x.band.bossHp)} health) in ${turns(Balance.killTurns(x.top.vector, x.band.bossHp, T))} turns · the plain rail in ${turns(Balance.killTurns(x.plain.vector, x.band.bossHp, T))} · a random rail in ${turns(x.randomTurns)}`);
		console.log(`       ${fmt(x.top.vector[3] / T)} gems fired a turn · ${fmt(x.top.synergy / T)} a turn over its gems alone${x.top.vector[Balance.RUNAWAY] > 0 ? ' · RUNS AWAY on fresh fights' : ''}\n`);
	}
	const loops = hunt.runaways || [];
	if (loops.length) {
		over += 1;
		const cores = Balance.runawayCores(hunt).slice(0, 3).map((c) => `${c.pair.map(name).join(' → ')} (${Math.round(c.share * 100)}%)`);
		console.log(`OVER ${loops.length} runaways: rails the game spends at ${Balance.RAIL_CAP} gems in a turn; most of them hold ${cores.join(', ')}`);
		console.log(`       e.g. ${C.character(loops[0].bowl).name || loops[0].bowl}: ${loops[0].rail.map(name).join(', ')}\n`);
	}
	if (!Object.keys(now).length) console.log('The hunt has nothing to read. Run: node tools/data-browser/balance.mjs hunt');
	console.log(over ? `${over} finding${over === 1 ? '' : 's'} over the limit.` : 'Every band is inside the limit, and nothing runs away.');
	return over ? 1 : 0;
}
