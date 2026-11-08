// Drives the real app in headless Chrome over the DevTools protocol and
// reports every console error and uncaught exception. Buttons are found by
// their screen-reader labels (Flutter's semantics tree), then tapped.
//
// Usage (serve build/web first, e.g. python -m http.server 8766):
//   node tool/web_check/drive.mjs http://127.0.0.1:8766/ build/web_shots
import { spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const url = process.argv[2] ?? 'http://127.0.0.1:8766/';
const outDir = process.argv[3] ?? 'build/web_shots';
mkdirSync(outDir, { recursive: true });

const chromePath = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const port = 9333;
const chrome = spawn(chromePath, [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${mkdtempSync(join(tmpdir(), 'lbr-chrome-'))}`,
  '--no-first-run',
  '--autoplay-policy=no-user-gesture-required',
  '--window-size=844,390',
  'about:blank',
]);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const problems = [];
const report = (kind, text) => {
  const line = `[${kind}] ${text}`;
  console.log(line);
  if (kind !== 'log') problems.push(line);
};

async function target() {
  for (let i = 0; i < 50; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = list.find((t) => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(200);
  }
  throw new Error('Chrome did not start');
}

const ws = new WebSocket(await target());
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let nextId = 1;
const pending = new Map();
ws.addEventListener('message', (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
    return;
  }
  if (msg.method === 'Runtime.consoleAPICalled') {
    const text = msg.params.args.map((a) => a.value ?? a.description ?? '').join(' ');
    const kind = ['error', 'warning', 'assert'].includes(msg.params.type) ? msg.params.type : 'log';
    report(kind, text.slice(0, 600));
  } else if (msg.method === 'Runtime.exceptionThrown') {
    const d = msg.params.exceptionDetails;
    report('exception', (d.exception?.description ?? d.text).slice(0, 800));
  } else if (msg.method === 'Log.entryAdded') {
    const e2 = msg.params.entry;
    if (e2.level === 'error') report('browser-error', `${e2.text} ${e2.url ?? ''}`);
  }
});
const send = (method, params = {}) =>
  new Promise((resolve) => {
    const id = nextId++;
    pending.set(id, resolve);
    ws.send(JSON.stringify({ id, method, params }));
  });

await send('Runtime.enable');
await send('Log.enable');
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', {
  width: 844, height: 390, deviceScaleFactor: 2, mobile: false,
});

async function evaluate(expression) {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  return r.result?.result?.value;
}

async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(join(outDir, `${name}.png`), Buffer.from(r.result.data, 'base64'));
  console.log(`[shot] ${name}`);
}

async function tapAt(x, y) {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
    await sleep(60);
  }
}

// Flutter builds its accessibility tree in the DOM once asked to.
async function enableSemantics() {
  await evaluate(`(() => {
    const p = document.querySelector('flt-semantics-placeholder');
    if (p) p.click();
    return !!p;
  })()`);
  await sleep(800);
}

async function find(label) {
  return evaluate(`(() => {
    const want = ${JSON.stringify(label)};
    const nodes = [...document.querySelectorAll('flt-semantics, [aria-label], [role]')];
    const hit = nodes.find((n) => (n.getAttribute('aria-label') ?? '').trim() === want
      || (n.textContent ?? '').trim() === want);
    if (!hit) return null;
    const r = hit.getBoundingClientRect();
    return r.width && r.height ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null;
  })()`);
}

async function tap(label, { optional = false } = {}) {
  for (let i = 0; i < 20; i++) {
    const at = await find(label);
    if (at) {
      await tapAt(at.x, at.y);
      console.log(`[tap] ${label}`);
      await sleep(600);
      return true;
    }
    await sleep(300);
    if (i === 5) await enableSemantics();
  }
  if (!optional) report('missing', `no button "${label}"`);
  return false;
}

// ---------------------------------------------------------------- session
await send('Page.navigate', { url });
await sleep(9000);
await shot('01_first_launch');
await enableSemantics();
await tap('Big Builder, Ages 5 to 7');
await sleep(1500);
await shot('02_home');

await tap('Play');
await sleep(1500);
await shot('03_workshop');
await tap('Legs');
await tap('Wheels');
await tap('Paint');
await tap('Robo blue, stripes');
await tap('Moves');
await tap('Tank tracks'); // locked: needs bolts, should shake, no crash
await shot('04_workshop_painted');
await tap('Test it!');
await sleep(1000);
await tapAt(422, 200); // skip the preview
await sleep(4000);
await shot('05_run');
await tap('Pause');
await sleep(500);
await shot('06_pause');
await tap('Keep going');
await sleep(20000); // course 1 is flat: let it finish
await shot('07_after_run');
await tap('OK', { optional: true }); // a sticker reveal, if any
await sleep(800);
await shot('08_result');
await tap('Next', { optional: true });
await sleep(1500);
await shot('09_map');
await tap('Course 2, 0 stars');
await sleep(800);
await shot('10_map_hint');
await tap('Home');
await sleep(1200);
await tap('Sticker book');
await sleep(1200);
await shot('11_stickers');
await tap('Home');
await sleep(1200);
await tap('Grown-ups');
await sleep(1200);
await shot('12_gate');
await tap('Close');
await sleep(1000);
await shot('13_back_home');

console.log(`\n=== ${problems.length} problem(s) ===`);
for (const p of problems) console.log(p);
ws.close();
chrome.kill();
process.exit(0);
