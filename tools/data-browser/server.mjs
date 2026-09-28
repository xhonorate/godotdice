import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, '../..');
const port = Number(process.env.PORT || 4173);
const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8' };

createServer(async (request, response) => {
	const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
	const relative = pathname === '/' ? 'index.html' : pathname === '/data/deep_cut.json' ? 'content/deep_cut.json' : pathname.slice(1);
	const root = pathname === '/data/deep_cut.json' ? projectRoot : here;
	const file = path.resolve(root, relative);
	if (!file.startsWith(root + path.sep)) {
		response.writeHead(403).end('Forbidden');
		return;
	}
	try {
		const body = await readFile(file);
		response.writeHead(200, { 'content-type': mime[path.extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
		response.end(body);
	} catch {
		response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' }).end('Not found');
	}
}).listen(port, '127.0.0.1', () => console.log(`Deep Cut data browser: http://127.0.0.1:${port}`));