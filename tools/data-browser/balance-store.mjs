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
// Beside each sweep, what list() shows of it (and the size of the sweep it describes, so a
// sweep written some other way is noticed), so the listing never parses a whole sweep.
const metaFor = (sweep) => path.join(DIR, `${sweep}.meta.json`);
const metaOf = (result, size) => ({ created: result.created, packHash: result.packHash, settings: result.settings, seconds: result.seconds, size });

export async function save(sweep, result) {
	await mkdir(DIR, { recursive: true });
	const file = fileFor(sweep);
	try { await stat(file); await rename(file, fileFor(sweep, true)); } catch { /* the first run */ }
	const text = JSON.stringify(result);
	await writeFile(file, text);
	await writeFile(metaFor(sweep), JSON.stringify(metaOf(result, Buffer.byteLength(text))));
}

export async function load(sweep, prev = false) {
	try { return JSON.parse(await readFile(fileFor(sweep, prev), 'utf8')); } catch { return null; }
}

const exists = async (file) => { try { return (await stat(file)).isFile(); } catch { return false; } };

// A sweep's sidecar, written afresh from the sweep itself when it is missing or stale.
async function metaLoad(sweep) {
	let size = -1;
	try { size = (await stat(fileFor(sweep))).size; } catch { return null; }
	try {
		const meta = JSON.parse(await readFile(metaFor(sweep), 'utf8'));
		if (meta && meta.size === size) return meta;
	} catch { /* none yet */ }
	const result = await load(sweep);
	if (!result) return null;
	const meta = metaOf(result, size);
	try { await writeFile(metaFor(sweep), JSON.stringify(meta)); } catch { /* read-only is fine */ }
	return meta;
}

// What has been run: each sweep's settings, pack and date, without its numbers.
export async function list() {
	const out = {};
	for (const sweep of SWEEPS) {
		const meta = await metaLoad(sweep);
		if (meta) out[sweep] = { created: meta.created, packHash: meta.packHash, settings: meta.settings, seconds: meta.seconds, hasPrev: await exists(fileFor(sweep, true)) };
	}
	return out;
}
