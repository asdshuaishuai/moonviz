// issue #28 基准：session_snapshot 增量成本（外部宿主视角，classic wasm）。
// 用法：node scripts/bench-snapshot.mjs [wasm 路径]
// 度量：100 节点板——未变更快照（缓存快路径）vs 单节点变更快照 vs 单次 apply。
// 2026-11-04 基线（M 系列本机）：unchanged ≈ 0.33ms / one-change ≈ 5.9ms / apply ≈ 4.6ms。
import { readFileSync } from 'node:fs';
const wasmPath = process.argv[2] || '_build/wasm/release/build/wasm/wasm.wasm';
const { instance } = await WebAssembly.instantiate(readFileSync(wasmPath), {});
const E = instance.exports;
const dec = new TextDecoder('utf-16le');
function readMoonstr(ptr) {
  const dv = new DataView(E.memory.buffer);
  const w = dv.getUint32(ptr + 4, true);
  if ((w >>> 28) === 0x5) {
    const len = w & 0x0fffffff;
    return dec.decode(new Uint8Array(E.memory.buffer, ptr + 8, len * 2));
  }
  const len = dv.getUint32(ptr - 4, true);
  return dec.decode(new Uint8Array(E.memory.buffer, ptr, len * 2));
}
function pushSlot(push, text) { for (const b of new TextEncoder().encode(text)) push(b, 1); }
function open(mbt) { E.in_reset(); pushSlot(E.in_push, mbt); return E.session_open_in(); }
function apply(h, op) { E.arg_reset(); pushSlot(E.arg_push, op); return readMoonstr(E.session_apply_human_in(h)); }
const snap = (h) => readMoonstr(E.session_snapshot(h));

const SEED = `---\nmoonbit:\n  backend: native\nmoonviz:\n  format: visual-document\n  revision: 2\n  title: T\n  entry: w\n  artboards:\n    - w\n---\n\n# T\n\n<!-- moonviz:artboard w -->\n\`\`\`mbt\n///| @moonviz:visual w\nfn visual_w() -> @decl.Prototype {\n  let page = @decl.prototype(name="w", width=390.0, height=844.0)\n  page\n}\n\`\`\`\n`;
const h = open(SEED);
if (h < 0) { console.log('open failed'); process.exit(1); }
for (let i = 0; i < 100; i++) {
  apply(h, `place w button b${i} - ${(i % 9) * 40 + 2} ${Math.floor(i / 9) * 72 + 2} 36 24`);
}
for (let i = 0; i < 5; i++) snap(h);           // warm
const N = 300;
let t0 = process.hrtime.bigint();
for (let i = 0; i < N; i++) snap(h);
let t1 = process.hrtime.bigint();
const unchangedUs = Number(t1 - t0) / 1e3 / N;

let sum = 0n; const M = 60;
for (let i = 0; i < M; i++) {
  apply(h, `update w b${i % 100} text=row${i}`);
  const a = process.hrtime.bigint();
  snap(h);
  const b = process.hrtime.bigint();
  sum += b - a;
}
const incrUs = Number(sum) / 1e3 / M;

t0 = process.hrtime.bigint();
for (let i = 0; i < 50; i++) apply(h, `update w b${i % 100} text=o${i}`);
t1 = process.hrtime.bigint();
const applyUs = Number(t1 - t0) / 1e3 / 50;

const s = snap(h);
const nodes = (s.match(/"id":"b\d+"/g) || []).length;
console.log(JSON.stringify({ board_nodes: nodes, unchanged_snapshot_us: +unchangedUs.toFixed(1), one_node_change_snapshot_us: +incrUs.toFixed(1), apply_op_us: +applyUs.toFixed(1), seq_seen: /"seq":(\d+)/.exec(s)[1] }));
