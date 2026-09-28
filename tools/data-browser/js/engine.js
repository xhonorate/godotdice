// The main thread's handle on the simulation worker: one promise per job, answers cached by
// their parameters, progress reported to whoever asked.

import * as Sim from './sim/simulate.js';

let worker = null;
let nextId = 1;
const pending = new Map();
const cache = new Map();
const listeners = new Set();

export function start(pack) {
	try {
		worker = new Worker(new URL('./worker.js', import.meta.url), { type: 'module' });
		worker.onmessage = (event) => {
			const { id, result, progress, error } = event.data;
			const job = pending.get(id);
			if (!job) return;
			if (progress !== undefined) { job.onProgress && job.onProgress(progress); return; }
			pending.delete(id);
			if (error) job.reject(new Error(error)); else job.resolve(result);
		};
		worker.onerror = (event) => { console.warn('worker failed, running inline', event.message); worker = null; };
		return post('pack', pack);
	} catch (error) {
		console.warn('no worker available, running inline', error);
		worker = null;
		return Promise.resolve(true);
	}
}

function post(type, params, onProgress) {
	if (!worker) {
		const jobs = { skillStats: Sim.skillStats, handStats: Sim.handStats, creatureTurn: Sim.creatureTurn, encounters: Sim.encounters, stones: Sim.stones, triggerOdds: Sim.triggerOdds };
		return Promise.resolve(type === 'pack' ? true : jobs[type](params, onProgress));
	}
	const id = nextId++;
	return new Promise((resolve, reject) => {
		pending.set(id, { resolve, reject, onProgress });
		worker.postMessage({ id, type, params });
	});
}

export function busy() { return pending.size > 0; }
export function onBusy(fn) { listeners.add(fn); return () => listeners.delete(fn); }
function notify() { for (const fn of listeners) fn(pending.size); }

// Run a job, or hand back the cached answer for identical parameters.
export function run(type, params, onProgress) {
	const key = type + ':' + JSON.stringify(params);
	if (cache.has(key)) return Promise.resolve(cache.get(key));
	notify();
	return post(type, params, onProgress).then((result) => { cache.set(key, result); notify(); return result; }, (error) => { notify(); throw error; });
}

export function cached(type, params) { return cache.get(type + ':' + JSON.stringify(params)); }
