/**
 * Smart UX M-S2 性能预算基准：set_data（注入 + 绑定影响面 diff）的宿主面计时。
 *
 * 为什么在宿主面测：引擎 classic wasm 零 import 红线 ⇒ 引擎内无时钟；
 * benchmark.mbt 的惯例是复杂度分析。宿主（Node/CLI 会话）有真钟——
 * 16ms 预算的语义本就是「宿主一次局部更新的成本」。
 *
 * 协议：行分帧，任何一行非空输出（stdout 或 stderr）都视为上一条命令的
 * 回执——与引擎 CLI 的「一命令一回执」契约一致，不挑 JSON 形态。
 * 退出码：均值 > 16ms × CI 噪声容差 3 = 48ms → 2；否则 0。
 * 运行：node scripts/bench-setdata.mjs [nodes=120] [rounds=30]
 */
import { spawn } from 'node:child_process';

const NODES = Number(process.argv[2] ?? '120');
const ROUNDS = Number(process.argv[3] ?? '30');
const BUDGET_MS = 16, TOLERANCE = 3;

// CLI REPL 每条回执后 fflush（cli/main.mbt 行协议契约）——管道模式逐行可达。
const cli = spawn('_build/native/release/build/cli/cli.exe', [], { stdio: ['pipe', 'pipe', 'pipe'] });
const replies = [];
function pump(bufRef, c) {
  let buf = bufRef.v + c;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const l = buf.slice(0, i);
    buf = buf.slice(i + 1);
    if (l.trim() !== '') replies.push(l);
  }
  bufRef.v = buf;
}
const soRef = { v: '' }, seRef = { v: '' };
cli.stdout.on('data', c => pump(soRef, c));
cli.stderr.on('data', c => pump(seRef, c));

function send(line) {
  return new Promise(res => {
    const before = replies.length;
    const tick = () => { if (replies.length > before) res(replies[replies.length - 1]); else setImmediate(tick); };
    cli.stdin.write(line + '\n');
    setImmediate(tick);
  });
}

await send('version');
await send(`create home 400 ${NODES * 6 + 60}`);
for (let i = 0; i < NODES; i++) {
  await send(`place home body_text n${i} - 20 ${20 + i * 6} 200 20`);
  await send(`update home n${i} text={{v.${i}}}`);
}
// 预热一次注入（路径/JIT 预热），随后正式计时
await send('data {"v":{"0":"warm"}}');
const times = [];
for (let r = 0; r < ROUNDS; r++) {
  const t0 = process.hrtime.bigint();
  await send(`data {"v":{"${r % NODES}":"r${r}"}}`);
  const t1 = process.hrtime.bigint();
  times.push(Number(t1 - t0) / 1e6);
}
const avg = times.reduce((a, b) => a + b, 0) / times.length;
const mx = Math.max(...times);
console.log(`[bench-setdata] nodes=${NODES} rounds=${ROUNDS} avg=${avg.toFixed(2)}ms max=${mx.toFixed(2)}ms budget=${BUDGET_MS}ms(×${TOLERANCE} tolerance)`);
cli.stdin.end('exit\n');
if (avg > BUDGET_MS * TOLERANCE) {
  console.error(`[bench-setdata] FAIL — 均值超过 16ms×${TOLERANCE} 预算`);
  process.exit(2);
}
console.log('[bench-setdata] PASS');
