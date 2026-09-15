import process from 'node:process';
import fsp from 'node:fs/promises';

// --- شیمِ حداقلیِ DOM برای بوتِ Godot web در Node (فقط smoke، نه بازی با UI واقعی) ---
const makeCanvas = () => {
  const el = {
    id: 'canvas', style: {}, width: 1280, height: 720,
    clientWidth: 1280, clientHeight: 720,
    getContext: () => null,
    getBoundingClientRect: () => ({ x: 0, y: 0, width: 1280, height: 720, top: 0, left: 0, right: 1280, bottom: 720, toJSON: () => ({}) }),
    addEventListener: () => {}, removeEventListener: () => {},
    setPointerCapture: () => {}, releasePointerCapture: () => {},
    focus: () => {},
  };
  return el;
};
globalThis.window = globalThis;
globalThis.self = globalThis;
window.localStorage = { getItem: () => null, setItem: () => {}, removeItem: () => {}, clear: () => {}, key: () => null, length: 0 };
window.location = new URL('http://localhost/index.html');
const stubCanvas = makeCanvas();
globalThis.document = {
  getElementById: (id) => { const k = String(id).replace('#',''); if (k === 'canvas') return stubCanvas; return { appendChild: () => {}, style: {}, remove: () => {}, addEventListener: () => {} }; },
  getElementsByTagName: () => [], querySelector: () => null,
  createElement: (tag) => (tag === 'canvas' ? makeCanvas() : { style: {}, getContext: () => null, addEventListener: () => {} }),
  addEventListener: () => {}, removeEventListener: () => {},
  documentElement: { style: {} }, body: { appendChild: () => {} },
};
Object.defineProperty(globalThis, 'navigator', { value: { userAgent: 'Mozilla/5.0 (Node.js emulated) Chrome/120 Safari/537.36', platform: 'linux', hardwareConcurrency: 4, maxTouchPoints: 0, language: 'fa-IR', mediaDevices: {}, getGamepads: () => [] }, configurable: true });
window.dispatchEvent = () => true;
window.alert = (msg) => { console.log('[ALERT]', msg); };
window.addEventListener = () => {}; window.removeEventListener = () => {};

// --- هَرنِس ---
const dir = process.env.NEXUS_SMOKE_DIR || 'build/web_smoke';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const absDir = path.resolve(dir);
const runtimeURL = pathToFileURL(path.join(absDir, 'runtime.js')).href;
process.chdir(absDir);
const { default: Godot } = await import(runtimeURL);


let sawPass = false;
const t = setTimeout(() => { console.error('[HARNESS] timeout'); process.exit(3); }, 240000);
const origExit = process.exit.bind(process);
process.exit = (code) => { clearTimeout(t); console.log('[HARNESS] exit', code, 'pass=', sawPass); origExit(code === 0 || sawPass ? 0 : 1); };
process.on('uncaughtException', (e) => { clearTimeout(t); console.log('[HARNESS] uncaught:', (e && e.message) || e, 'pass=', sawPass); origExit(sawPass ? 0 : 1); });
process.on('unhandledRejection', (e) => { clearTimeout(t); console.log('[HARNESS] rejection:', (e && e.message) || e, 'pass=', sawPass); origExit(sawPass ? 0 : 1); });

const wasmBuf = await fsp.readFile(path.join(absDir, 'index.wasm'));
const Module = {
  canvas: stubCanvas,
  wasmBinary: wasmBuf.buffer.slice(wasmBuf.byteOffset, wasmBuf.byteOffset + wasmBuf.byteLength),
  print: (s) => { console.log('[OUT]', s); if (String(s).includes('[SMOKE][PASS]')) sawPass = true; },
  printErr: (s) => console.log('[ERR]', s),
};

try {
  const engine = await Godot(Module);
  console.log('[HARNESS] runtime initialized');
  try { engine.initConfig({ canvasResizePolicy: 0, canvas: stubCanvas, locale: 'fa' }); console.log('[HARNESS] initConfig ok'); } catch (e2) { console.log('[HARNESS] initConfig err:', e2.message); }
  const pck = await fsp.readFile(path.join(absDir, 'index.pck'));
  engine.copyToFS('/index.pck', new Uint8Array(pck));
  console.log('[HARNESS] pck loaded, starting main');
  engine.callMain(['--main-pack', '/index.pck', '--audio-driver', 'Dummy', '--rendering-driver', 'dummy', '--display-driver', 'headless', '--script', 'res://preview/SmokeWeb.gd']);
  console.log('[HARNESS] callMain returned');
} catch (e) {
  clearTimeout(t);
  console.log('[HARNESS] engine threw:', e && e.stack ? e.stack : (e && e.message ? e.message : e));
  origExit(sawPass ? 0 : 1);
}
