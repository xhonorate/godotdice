// The Balance page's sweeps: run on a pool of workers (one per core, less one, at most 15),
// kept by the server in build/balance so a sweep run once is there on every later visit, and
// reported to whoever is listening while they run. One sweep runs at a time.

import * as Balance from './sim/balance.js';

let pack = null;
let hash = '';
let pool = [];
const results = new Map();
const previous = new Map();
const loading = new Map();
let active = null;
const listeners = new Set();

export function init(loaded) { pack = loaded; hash = Balance.packHash(loaded); }
export const packHash = () => hash;
export const running = () => active;
export function onChange(fn) { listeners.add(fn); return () => listeners.delete(fn); }
function notify() { for (const fn of listeners) { try { fn(active); } catch (error) { console.error(error); } } }

// A sweep's last saved result (and the run before it), from the server once and then from memory.
export function load(sweep) {
	if (results.has(sweep)) return Promise.resolve(results.get(sweep));
	if (!loading.has(sweep)) {
		loading.set(sweep, Promise.all([fetchJson(`api/balance/${sweep}`), fetchJson(`api/balance/${sweep}?v=prev`)]).then(([current, prev]) => {
			if (current && !results.has(sweep)) results.set(sweep, current);
			if (prev && !previous.has(sweep)) previous.set(sweep, prev);
			return results.get(sweep) || null;
		}));
	}
	return loading.get(sweep);
}
export const get = (sweep) => results.get(sweep) || null;
export const getPrevious = (sweep) => previous.get(sweep) || null;

async function fetchJson(url) {
	try { const r = await fetch(url, { cache: 'no-store' }); return r.ok ? await r.json() : null; } catch { return null; }
}

function poolSize() {
	const cores = Number(navigator.hardwareConcurrency || 4);
	return Math.max(1, Math.min(15, cores - 1));
}

function ensurePool() {
	if (pool.length) return pool;
	for (let i = 0; i < poolSize(); i++) {
		const worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });
		worker.postMessage({ id: 0, type: 'pack', params: pack });
		pool.push(worker);
	}
	return pool;
}

function dropPool() {
	for (const worker of pool) worker.terminate();
	pool = [];
}

// Run a sweep, a round of tasks at a time (see Balance.startJob). `context.leads` is needed
// for the sweeps that set gems beside others; `weights` are what the hunt hunts by. Resolves
// with the result, already kept by the server; rejects if cancelled.
export async function run(sweep, settings, context = {}, weights = Balance.DEFAULT_WEIGHTS) {
	if (active) throw new Error(`${active.sweep} is already running`);
	const job = Balance.startJob(sweep, settings, context, weights);
	const started = performance.now();
	let cancelled = false;
	active = { sweep, done: 0, total: Math.max(1, Balance.estimateTasks(job)), round: 0, started,
		cancel: () => { cancelled = true; dropPool(); active = null; notify(); if (abortRound) abortRound(new Error('cancelled')); } };
	notify();
	let finished = 0;
	for (let tasks = Balance.nextTasks(job); tasks; tasks = Balance.nextTasks(job)) {
		if (active) { active.total = finished + Math.max(tasks.length, Balance.estimateTasks(job)); active.round = job.round; notify(); }
		const out = await playRound(tasks, (done) => { if (active) { active.done = finished + done; notify(); } });
		if (cancelled || !active) throw new Error('cancelled');
		finished += tasks.length;
		Balance.takeResults(job, out);
	}
	const seconds = Math.round((performance.now() - started) / 1000);
	const result = Balance.finishJob(job, { packHash: hash, created: new Date().toISOString(), seconds, leads: context.leads });
	if (results.has(sweep)) previous.set(sweep, results.get(sweep));
	results.set(sweep, result);
	active = null;
	notify();
	fetch(`api/balance/${sweep}`, { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify(result) }).catch((e) => console.warn('could not keep the sweep', e));
	return result;
}

// One round of tasks on the pool; `report(done)` as each comes back. A cancel rejects it.
let abortRound = null;
function playRound(tasks, report) {
	const workers = ensurePool();
	const out = new Array(tasks.length);
	return new Promise((resolve, reject) => {
		abortRound = reject;
		if (!tasks.length) { resolve(out); return; }
		let next = 0, done = 0;
		const feed = (worker) => {
			if (next >= tasks.length) return;
			const id = next++ + 1;
			worker.postMessage({ id, type: 'balanceTask', params: tasks[id - 1] });
		};
		for (const worker of workers) {
			worker.onmessage = (event) => {
				const { id, result, error } = event.data;
				if (id === 0 || event.data.progress !== undefined) return;
				if (error) { dropPool(); active = null; notify(); reject(new Error(error)); return; }
				out[id - 1] = result;
				done += 1;
				report(done);
				if (done === tasks.length) resolve(out); else feed(worker);
			};
			worker.onerror = (event) => { dropPool(); active = null; notify(); reject(new Error(event.message || 'worker failed')); };
			feed(worker);
		}
	});
}

export function cancel() { if (active) active.cancel(); }
