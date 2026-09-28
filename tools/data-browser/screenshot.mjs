// Screenshot pages of the balance browser with headless Chrome over the DevTools protocol,
// waiting real seconds so the simulation worker has finished, and printing any console error.
// The server must be running (node tools/data-browser/server.mjs). Usage:
//   node tools/data-browser/screenshot.mjs build/browser-shots 8 "#/overview" "#/skills/STRIKE?tab=rules" ...
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';

const [outDir, waitSeconds, ...routes] = process.argv.slice(2);
mkdirSync(outDir, { recursive: true });
const port = 9333;
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--remote-debugging-port=${port}`, '--user-data-dir=/tmp/cdp-prof', '--window-size=1440,900', 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let wsUrl = null;
for (let i = 0; i < 40 && !wsUrl; i++) { await sleep(250); try { const v = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json(); wsUrl = v.webSocketDebuggerUrl; } catch {} }
if (!wsUrl) { console.error('chrome did not start'); chrome.kill(); process.exit(1); }
const ws = new WebSocket(wsUrl);
await new Promise((r) => ws.addEventListener('open', r));
let nextId = 1;
const pending = new Map();
const logs = [];
ws.addEventListener('message', (e) => {
	const msg = JSON.parse(e.data);
	if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
	if (msg.method === 'Runtime.exceptionThrown') logs.push(`EXCEPTION: ${msg.params.exceptionDetails.text} ${msg.params.exceptionDetails.exception?.description || ''}`);
	if (msg.method === 'Runtime.consoleAPICalled' && ['error', 'warning'].includes(msg.params.type)) logs.push(`${msg.params.type.toUpperCase()}: ${msg.params.args.map((a) => a.value || a.description).join(' ')}`);
});
const send = (method, params = {}, sessionId) => new Promise((resolve) => { const id = nextId++; pending.set(id, resolve); ws.send(JSON.stringify({ id, method, params, sessionId })); });
const created = await send('Target.createTarget', { url: 'about:blank' });
if (!created.result) { console.error('createTarget failed', JSON.stringify(created)); chrome.kill(); process.exit(1); }
const { targetId } = created.result;
const { result: { sessionId } } = await send('Target.attachToTarget', { targetId, flatten: true });
await send('Page.enable', {}, sessionId);
await send('Runtime.enable', {}, sessionId);
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false }, sessionId);
for (const route of routes) {
	await send('Page.navigate', { url: 'about:blank' }, sessionId);
	await sleep(200);
	await send('Page.navigate', { url: `http://127.0.0.1:4173/${route}` }, sessionId);
	await sleep(Number(waitSeconds) * 1000);
	const { result } = await send('Page.captureScreenshot', { format: 'png' }, sessionId);
	const name = route.replace(/^#\//, '').replace(/[^a-z0-9]+/gi, '_') || 'root';
	writeFileSync(`${outDir}/${name}.png`, Buffer.from(result.data, 'base64'));
	console.log(`shot ${name}`);
}
console.log(logs.length ? logs.join('\n') : 'no console errors');
ws.close();
chrome.kill();
