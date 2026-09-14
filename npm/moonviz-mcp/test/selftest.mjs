// moonviz-mcp 自检（不启动长驻服务）：验证平台二进制可解析、可执行，
// 并对 JSON-RPC initialize 做一次完整往返。
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import process from 'node:process';

const require = createRequire(import.meta.url);

// 1. 平台二进制可解析（darwin-arm64 构建机上应存在）
const platform = `${process.platform}-${process.arch}`;
let bin = null;
try {
  const pkg = require.resolve(`moonviz-bin-${platform}/package.json`);
  const candidate = join(pkg, '..', 'bin', 'moonviz-mcp');
  if (existsSync(candidate)) bin = candidate;
} catch { /* 平台包未安装（其他平台 CI 上）：仅跳过二进制段 */ }

if (bin) {
  const out = await new Promise((resolveTest, reject) => {
    const child = spawn(bin, []);
    let buf = '';
    child.stdout.on('data', c => (buf += c));
    child.stderr.on('data', c => (buf += c));
    child.on('error', reject);
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'selftest', version: '0' } } }) + '\n');
    setTimeout(() => { child.kill(); resolveTest(buf); }, 3000);
  });
  const line = out.split('\n').find(l => l.startsWith('{'));
  const resp = JSON.parse(line);
  assert.equal(resp.result.serverInfo.name, 'moonviz', 'initialize 应返回 serverInfo.name=moonviz');
  console.log('moonviz-mcp selftest passed: platform binary', platform, '· JSON-RPC initialize OK');
} else {
  console.log('moonviz-mcp selftest skipped: no prebuilt binary for', platform, '（回退模式请在具备 moon 工具链的环境验证）');
}
