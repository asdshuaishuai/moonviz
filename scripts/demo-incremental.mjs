/**
 * Smart UX M-S2 宿主增量更新演示（webview 局部 patch 的可运行形态）。
 *
 * 流程：CLI 会话内建文档（绑定节点）→ 全量渲染一次作底版 →
 * 循环注入数据：set_data 给 changed 清单 → 对每个 changed 节点
 * render_node_svg 取新片段 → 在底版 SVG 里按 id + 括号深度替换该 <g>。
 *
 * 正确性证明（退出码门）：patch 后的 SVG 必须与全量重渲逐字节一致——
 * 「只换 changed 节点」与「整文档重渲」输出等价，增量才是安全的。
 * 运行：node scripts/demo-incremental.mjs [rounds=5]
 */
import { spawn } from 'node:child_process';

const ROUNDS = Number(process.argv[2] ?? '5');
const cli = spawn('_build/native/release/build/cli/cli.exe', [], { stdio: ['pipe', 'pipe', 'pipe'] });
const replies = [];
let so = '', se = '';
cli.stdout.on('data', c => { so += c; let i; while ((i = so.indexOf('\n')) >= 0) { const l = so.slice(0, i); so = so.slice(i + 1); if (l.trim()) replies.push(l); } });
cli.stderr.on('data', c => { se += c; let i; while ((i = se.indexOf('\n')) >= 0) { const l = se.slice(0, i); se = se.slice(i + 1); if (l.trim()) replies.push(l); } });
const send = line => new Promise(res => { const b = replies.length; const tick = () => { if (replies.length > b) res(JSON.parse(replies[replies.length - 1])); else setImmediate(tick); }; cli.stdin.write(line + '\n'); setImmediate(tick); });

await send('version');
await send('create home 400 200');
const NODES = 6;
for (let i = 0; i < NODES; i++) {
  await send(`place home body_text n${i} - 20 ${20 + i * 26} 360 22`);
  await send(`update home n${i} text={{v.${i}}}`);
}
await send('data {"v":{"0":"零","1":"一","2":"二","3":"三","4":"四","5":"五"}}');

let baseSvg = (await send('export-svg home')).svg;

/** 按 id 替换 SVG 里 depth 归零的 <g id="n_id">…</g> 块 */
function patchNode(svg, id, fragment) {
  const startTag = `<g id="n_${id}"`;
  const start = svg.indexOf(startTag);
  if (start < 0) return svg;
  let depth = 0, i = start;
  while (i < svg.length) {
    if (svg.startsWith('<g', i)) { depth += 1; i += 2; continue; }
    if (svg.startsWith('</g>', i)) {
      depth -= 1;
      if (depth === 0) return svg.slice(0, start) + fragment + svg.slice(i + 4);
      i += 4;
      continue;
    }
    i += 1;
  }
  return svg;
}

let patched = baseSvg;
let totalPatchMs = 0, totalFullMs = 0;
const names = ['零', '一', '二', '三', '四', '五'];
for (let r = 0; r < ROUNDS; r++) {
  const data = {};
  // 每轮改两个节点的值（模拟部分数据更新）
  data.v = {};
  data.v[r % NODES] = `r${r}`;
  data.v[(r + 2) % NODES] = `s${r}`;
  const t0 = process.hrtime.bigint();
  const resp = await send(`data ${JSON.stringify(data)}`);
  const changed = resp.changed ?? [];
  for (const c of changed) {
    const fragResp = await send(`render-node-svg home ${c.id}`);
    patched = patchNode(patched, c.id, fragResp.svg);
  }
  const t1 = process.hrtime.bigint();
  // 全量重渲对照
  const full = (await send('export-svg home')).svg;
  const t2 = process.hrtime.bigint();
  totalPatchMs += Number(t1 - t0) / 1e6;
  totalFullMs += Number(t2 - t1) / 1e6;
  const identical = patched === full;
  console.log(`round ${r}: changed=${changed.length} patch=${(Number(t1 - t0) / 1e6).toFixed(1)}ms full=${(Number(t2 - t1) / 1e6).toFixed(1)}ms equivalent=${identical}`);
  if (!identical) {
    console.error('FAIL — patch 后与全量重渲不等价');
    cli.stdin.end();
    process.exit(2);
  }
  // 数据一致性抽查：被改的节点在 patched 里是新值
  for (const k of Object.keys(data.v)) {
    if (!patched.includes(data.v[k])) {
      console.error(`FAIL — n${k} 未更新为 ${data.v[k]}`);
      cli.stdin.end();
      process.exit(2);
    }
  }
}
cli.stdin.end('exit\n');
console.log(`[demo-incremental] PASS — ${ROUNDS} 轮局部 patch 与全量重渲逐字节等价（patch 平均 ${(totalPatchMs / ROUNDS).toFixed(1)}ms vs full ${(totalFullMs / ROUNDS).toFixed(1)}ms，含 CLI 往返）`);
