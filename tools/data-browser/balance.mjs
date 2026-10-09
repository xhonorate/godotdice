// Run balance sweeps from the command line, on every core, into build/balance/ where the
// Balance page reads them (the previous run kept beside each as <sweep>.prev.json).
//
//   node tools/data-browser/balance.mjs [gems|cutclarity|inclusions|pairs|rails|all] [--workers N]
//        [--turns N] [--samples N] [--carat N] [--seed N] [--hosts N]
//
// The pairs and rails sweeps read which gem a rail's rerolls chase from the gems sweep, so
// `all` runs gems first. Settings not given are the page's defaults (js/sim/balance.js).

import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads';
import { readFile } from 'node:fs/promises';
import { availableParallelism } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as C from './js/sim/content.js';
import * as Balance from './js/sim/balance.js';

const here = path.dirname(fileURLToPath(import.meta.url));

if (!isMainThread) {
	C.setPack(workerData.pack);
	parentPort.on('message', ({ id, task }) => parentPort.postMessage({ id, result: Balance.runTask(task) }));
} else {
	const Store = await import('./balance-store.mjs');
	const args = process.argv.slice(2);
	const option = (name) => { const i = args.indexOf(`--${name}`); return i >= 0 ? Number(args[i + 1]) : undefined; };
	const wanted = args.find((a) => !a.startsWith('--') && !/^\d+$/.test(a)) || 'all';
	const sweeps = wanted === 'all' ? Balance.SWEEPS : [wanted];
	for (const sweep of sweeps) if (!Balance.SWEEPS.includes(sweep)) { console.error(`No sweep called ${sweep}. Try one of: ${Balance.SWEEPS.join(', ')}, all`); process.exit(2); }
	const pack = JSON.parse(await readFile(path.resolve(here, '../../content/deep_cut.json'), 'utf8'));
	C.setPack(pack);
	const settings = { ...Balance.DEFAULTS, samples: { ...Balance.DEFAULTS.samples } };
	for (const key of ['turns', 'carat', 'seed', 'hosts']) if (option(key) !== undefined) settings[key] = option(key);
	if (option('samples') !== undefined) for (const sweep of Balance.SWEEPS) settings.samples[sweep] = option('samples');
	const count = Math.max(1, option('workers') ?? Math.max(1, availableParallelism() - 1));
	const workers = Array.from({ length: count }, () => new Worker(fileURLToPath(import.meta.url), { workerData: { pack } }));
	const hash = Balance.packHash(pack);

	const run = (sweep, context) => new Promise((resolve, reject) => {
		const tasks = Balance.tasksFor(sweep, settings, context);
		const results = new Array(tasks.length);
		let next = 0, done = 0;
		const started = Date.now();
		const feed = (worker) => { if (next < tasks.length) { const id = next++; worker.postMessage({ id, task: tasks[id] }); } };
		for (const worker of workers) {
			worker.removeAllListeners('message');
			worker.removeAllListeners('error');
			worker.on('error', reject);
			worker.on('message', ({ id, result }) => {
				results[id] = result;
				done += 1;
				const seconds = (Date.now() - started) / 1000;
				process.stdout.write(`\r${sweep}: ${done}/${tasks.length} tasks · ${seconds.toFixed(0)}s · about ${Math.max(0, (seconds / done) * (tasks.length - done)).toFixed(0)}s to go   `);
				if (done === tasks.length) {
					process.stdout.write('\n');
					resolve(Balance.assemble(sweep, tasks, results, { packHash: hash, created: new Date().toISOString(), seconds: Math.round(seconds), leads: context.leads }));
				} else feed(worker);
			});
			feed(worker);
		}
	});

	let gems = await Store.load('gems');
	for (const sweep of sweeps) {
		const context = {};
		if (sweep === 'pairs' || sweep === 'rails') {
			if (!gems || gems.packHash !== hash) { console.log(`${sweep} reads the gems sweep: running gems first`); gems = await run('gems', {}); await Store.save('gems', gems); }
			context.leads = Balance.leadsFrom(gems);
		}
		const result = await run(sweep, context);
		await Store.save(sweep, result);
		if (sweep === 'gems') gems = result;
		console.log(`${sweep}: saved to ${path.relative(process.cwd(), path.join(Store.DIR, `${sweep}.json`))}`);
	}
	await Promise.all(workers.map((w) => w.terminate()));
}
