// A static server for the balance browser. Serves this folder, and the live content pack at
// /data/deep_cut.json, with caching off so an edit to the pack shows on the next reload.
//
//   node tools/data-browser/server.mjs            # http://127.0.0.1:4173
//   PORT=5000 node tools/data-browser/server.mjs
//
// Pictures come from tools/data-browser/assets, made by:
//   /path/to/Godot --path . --script tools/browser_assets.gd

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, '../..');
const port = Number(process.env.PORT || 4173);
const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
	'.json': 'application/json; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon' };

createServer(async (request, response) => {
	const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
	let root = here;
	let relative = pathname === '/' ? 'index.html' : pathname.slice(1);
	if (pathname === '/data/deep_cut.json') { root = projectRoot; relative = 'content/deep_cut.json'; }
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
