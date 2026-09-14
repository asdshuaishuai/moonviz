#!/usr/bin/env node
// moonviz-mcp 启动器：优先使用平台预编译二进制（零编译、毫秒级启动），
// 找不到时回退 `moon run --target native mcp`（需要 MoonBit 工具链 + 引擎目录）。
//
// MCP 客户端配置：
//   { "command": "npx", "args": ["-y", "moonviz-mcp"] }

import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import process from 'node:process';

const requireFromModule = createRequire(import.meta.url);
const requireFromCwd = createRequire(join(process.cwd(), 'index.js'));

function resolvePackageJson(name) {
  // 双路径解析：包自身链（标准安装）+ cwd 链（npx / file: symlink 场景）
  for (const req of [requireFromModule, requireFromCwd]) {
    try { return req.resolve(`${name}/package.json`); } catch { /* try next */ }
  }
  return null;
}

function findPlatformBinary() {
  const platform = `${process.platform}-${process.arch}`;
  const pkg = resolvePackageJson(`moonviz-bin-${platform}`);
  if (!pkg) return null;
  const bin = join(pkg, '..', 'bin', 'moonviz-mcp');
  return existsSync(bin) ? bin : null;
}

function findMoon() {
  const candidates = [
    process.env.MOONVIZ_MOON,
    process.env.MOON,
    join(process.env.HOME ?? '', '.moon/bin/moon'),
    '/opt/homebrew/bin/moon',
    '/usr/local/bin/moon',
  ].filter(Boolean);
  for (const c of candidates) if (existsSync(c)) return c;
  return null;
}

function findEngineDir() {
  const explicit = process.env.MOONVIZ_DIR;
  if (explicit && existsSync(join(explicit, 'mcp', 'moon.pkg'))) return resolve(explicit);
  // npm 全局/npx 缓存中无引擎源码；仅供相邻 clone 场景
  return null;
}

function fail(message) {
  console.error(`[moonviz-mcp] ${message}`);
  process.exit(1);
}

const binary = findPlatformBinary();
if (binary) {
  const child = spawn(binary, [], { stdio: 'inherit' });
  child.on('error', e => fail(`二进制启动失败：${e.message}`));
  child.on('exit', code => process.exit(code ?? 1));
} else {
  const platform = `${process.platform}-${process.arch}`;
  const moon = findMoon();
  const dir = findEngineDir();
  if (!moon || !dir) {
    fail([
      `当前平台（${platform}）没有预编译二进制包，且回退条件不满足。`,
      '两种解决方式：',
      '  1. 安装对应平台包：npm i -g moonviz-bin-' + platform + '（若已发布）',
      '  2. 回退模式需要：moon 工具链（https://docs.moonbitlang.com/）+ 设置 MOONVIZ_DIR 指向 moonviz 引擎仓库',
      `     当前检测：moon=${moon ? '✓' : '✗'}  MOONVIZ_DIR=${dir ? '✓' : '✗'}`,
    ].join('\n'));
  }
  const child = spawn(moon, ['run', '--target', 'native', 'mcp'], {
    cwd: dir,
    stdio: 'inherit',
  });
  child.on('error', e => fail(`moon 启动失败：${e.message}`));
  child.on('exit', code => process.exit(code ?? 1));
}
