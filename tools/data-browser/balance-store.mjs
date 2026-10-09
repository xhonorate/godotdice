// Where balance sweeps are kept: build/balance/<sweep>.json, the run before it beside it as
// <sweep>.prev.json so a page can say what a content change moved. The server and
// balance.mjs both write here; the Balance page reads it through the server.

import { mkdir, readFile, writeFile, rename, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { SWEEPS } from './js/sim/balance.js';

const here = path.dirname(fileURLToPath(import.meta.url));
export const DIR = path.resolve(here, '../../build/balance');

const fileFor = (sweep, prev = false) => {
	if (!SWEEPS.includes(sweep)) throw new Error(`No sweep called ${sweep}`);
	return path.join(DIR, `${sweep}${prev ? '.prev' : ''}.json`);
};

export async function save(sweep, result) {
	await mkdir(DIR, { recursive: true });
	const file = fileFor(sweep);
	try { await stat(file); await rename(file, fileFor(sweep, true)); } catch { /* the first run */ }
	await writeFile(file, JSON.stringify(result));
}

export async function load(sweep, prev = false) {
	try { return JSON.parse(await readFile(fileFor(sweep, prev), 'utf8')); } catch { return null; }
}

// What has been run: each sweep's settings, pack and date, without its numbers.
export async function list() {
	const out = {};
	for (const sweep of SWEEPS) {
		const result = await load(sweep);
		if (result) out[sweep] = { created: result.created, packHash: result.packHash, settings: result.settings, seconds: result.seconds, hasPrev: Boolean(await load(sweep, true)) };
	}
	return out;
}
