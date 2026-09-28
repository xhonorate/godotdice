// The simulation, off the main thread. Messages: {id, type, params}; answers: {id, result} or
// {id, progress} along the way, or {id, error}.

import { setPack } from './sim/content.js';
import * as Sim from './sim/simulate.js';

const jobs = { skillStats: Sim.skillStats, handStats: Sim.handStats, creatureTurn: Sim.creatureTurn, encounters: Sim.encounters, stones: Sim.stones, triggerOdds: Sim.triggerOdds };

self.onmessage = (event) => {
	const { id, type, params } = event.data;
	if (type === 'pack') { setPack(params); self.postMessage({ id, result: true }); return; }
	const job = jobs[type];
	if (!job) { self.postMessage({ id, error: `unknown job ${type}` }); return; }
	try {
		const result = job(params, (progress) => self.postMessage({ id, progress }));
		self.postMessage({ id, result });
	} catch (error) {
		self.postMessage({ id, error: String(error && error.stack || error) });
	}
};
