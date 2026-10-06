// A static server for the balance browser. Serves this folder, and the live content pack at
// /data/deep_cut.json, with caching off so an edit to the pack shows on the next reload.
//
//   node tools/data-browser/server.mjs            # http://127.0.0.1:4173
//   PORT=5000 node tools/data-browser/server.mjs
//
// Pictures come from tools/data-browser/assets, made by:
//   /path/to/Godot --path . --script tools/browser_assets.gd
//
// The Soundtrack page also writes: /api/music/* edits drafts of the pieces in
// content/score.json, renders them with Godot and adopts them into audio/music (see music.mjs).
// The server listens on this machine only. Run `npm install` in this folder once for the Ogg
// encoder; Godot is found on the path, beside the project or through GODOT_BIN.

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as Music from './music.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, '../..');
const port = Number(process.env.PORT || 4173);
const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
	'.json': 'application/json; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.ogg': 'audio/ogg', '.wav': 'audio/wav', '.mid': 'audio/midi' };

createServer(async (request, response) => {
	const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
	if (pathname.startsWith('/api/music')) {
		try {
			await musicApi(request, response, pathname);
		} catch (error) {
			sendJson(response, 400, { error: String(error.message || error) });
		}
		return;
	}
	let root = here;
	let relative = pathname === '/' ? 'index.html' : pathname.slice(1);
	if (pathname === '/data/deep_cut.json') { root = projectRoot; relative = 'content/deep_cut.json'; }
	// The pieces' audio: what is live, and what a draft rendered.
	if (pathname.startsWith('/music/live/')) { root = Music.LIVE_DIR; relative = pathname.slice('/music/live/'.length); }
	if (pathname.startsWith('/music/draft/')) { root = Music.DRAFT_DIR; relative = pathname.slice('/music/draft/'.length); }
	const file = path.resolve(root, relative);
	if (!file.startsWith(root + path.sep)) { response.writeHead(403).end('Forbidden'); return; }
	try {
		const info = await stat(file);
		if (!info.isFile()) throw new Error('not a file');
		const body = await readFile(file);
		response.writeHead(200, { 'content-type': mime[path.extname(file)] || 'application/octet-stream', 'cache-control': path.extname(file) === '.png' ? 'max-age=3600' : 'no-store' });
		response.end(body);
	} catch {
		response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' }).end('Not found');
	}
}).listen(port, '127.0.0.1', () => console.log(`Deep Cut balance browser: http://127.0.0.1:${port}`));

function sendJson(response, code, body) {
	response.writeHead(code, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' }).end(JSON.stringify(body));
}

async function bodyOf(request) {
	let text = '';
	for await (const part of request) {
		text += part;
		if (text.length > 1e6) throw new Error('body too large');
	}
	return text ? JSON.parse(text) : {};
}

// GET    /api/music                    the score, with every piece's live and draft state
// GET    /api/music/status             the render queue (cheap; polled while rendering)
// PUT    /api/music/<id>/draft         save a draft's spec (made from the live one if new)
// DELETE /api/music/<id>/draft         discard it: the live version stays as it is
// POST   /api/music/<id>/render        queue the draft for rendering
// POST   /api/music/<id>/adopt         make the rendered draft the live version
// GET    /api/music/<id>/notes?v=      every note of the live or draft version
// GET    /api/music/<id>/midi?v=       the same as a MIDI file
async function musicApi(request, response, pathname) {
	const parts = pathname.split('/').filter(Boolean).slice(2);
	const method = request.method;
	if (parts.length === 0 && method === 'GET') {
		const score = await Music.readScore();
		const pieces = {};
		for (const [id, spec] of Object.entries(score.tracks)) pieces[id] = { live: await Music.liveState(id, spec), draft: await Music.draftState(id) };
		sendJson(response, 200, { score, pieces, queue: Music.queueState(), godot: Music.findGodot() });
		return;
	}
	if (parts.length === 1 && parts[0] === 'status' && method === 'GET') {
		sendJson(response, 200, Music.queueState());
		return;
	}
	const [id, action] = parts;
	const score = await Music.readScore();
	if (!Music.validId(id) || !score.tracks[id]) throw new Error(`No piece called ${id}`);
	const version = new URL(request.url, 'http://localhost').searchParams.get('v') === 'draft' ? 'draft' : 'live';
	if (action === 'draft' && method === 'PUT') {
		const spec = await bodyOf(request);
		if (!spec || typeof spec !== 'object' || Array.isArray(spec)) throw new Error('a spec is an object');
		await Music.saveDraft(id, spec);
		Music.touched();
	} else if (action === 'draft' && method === 'DELETE') {
		await Music.discardDraft(id);
		Music.touched();
	} else if (action === 'render' && method === 'POST') {
		if (!(await Music.draftState(id))) await Music.saveDraft(id, score.tracks[id]);
		Music.enqueue(id);
	} else if (action === 'adopt' && method === 'POST') {
		await Music.adoptDraft(id);
		Music.touched();
	} else if (action === 'notes' && method === 'GET') {
		const notes = await Music.notesFor(id, version);
		if (!notes) throw new Error(`${id} has no ${version} render`);
		sendJson(response, 200, notes);
		return;
	} else if (action === 'midi' && method === 'GET') {
		const notes = await Music.notesFor(id, version);
		if (!notes) throw new Error(`${id} has no ${version} render`);
		const spec = version === 'draft' ? (await Music.draftState(id)).spec : score.tracks[id];
		const body = Music.midiFrom(notes, spec, spec.name || id);
		response.writeHead(200, { 'content-type': 'audio/midi', 'content-disposition': `attachment; filename="${id}${version === 'draft' ? '_draft' : ''}.mid"`, 'cache-control': 'no-store' }).end(body);
		return;
	} else {
		throw new Error(`${method} ${pathname} is not a thing the server does`);
	}
	const fresh = await Music.readScore();
	sendJson(response, 200, { id, spec: fresh.tracks[id], live: await Music.liveState(id, fresh.tracks[id]), draft: await Music.draftState(id), queue: Music.queueState() });
}
