// CLI 会话层（low-level）：进程编排 + JSON 行协议解析。
// 说明：协议是换行分帧的 JSON——每条命令一行，每行输出一个 JSON 值。

import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const requireFromModule = createRequire(import.meta.url);
const requireFromCwd = createRequire(join(process.cwd(), 'index.js'));

/** 引擎返回 { ok:false } 时抛出；error 为引擎错误码，detail 保留完整响应。 */
export class EngineError extends Error {
  constructor(error, detail) {
    super(error);
    this.name = 'EngineError';
    this.error = error;
    this.detail = detail;
  }
}

/** 默认引擎目录：SDK 包位于 moonviz/sdk/node/src 下，向上三级即引擎根。 */
export function defaultMoonvizDir() {
  const candidate = resolve(HERE, '..', '..', '..');
  return existsSync(join(candidate, 'cli', 'moon.pkg')) ? candidate : null;
}

/**
 * 定位预编译 CLI 二进制（moonviz-bin-<platform> 平台包或 MOONVIZ_CLI_BIN）。
 * 命中时整个会话不再依赖 moon 工具链与引擎源码目录。
 */
export function findPrebuiltCli() {
  const explicit = process.env.MOONVIZ_CLI_BIN;
  if (explicit && existsSync(explicit)) return explicit;
  const platform = `${process.platform}-${process.arch}`;
  for (const req of [requireFromModule, requireFromCwd]) {
    try {
      const pkg = req.resolve(`moonviz-bin-${platform}/package.json`);
      const bin = join(pkg, '..', 'bin', 'moonviz-cli');
      if (existsSync(bin)) return bin;
    } catch { /* 平台包未安装，继续 */ }
  }
  return null;
}

function findMoon() {
  const env = process.env.MOONVIZ_MOON ?? process.env.MOON ?? process.env.PATH ?? '';
  for (const dir of env.split(':')) {
    if (!dir) continue;
    const p = join(dir, 'moon');
    if (existsSync(p)) return p;
  }
  const home = process.env.HOME ?? process.env.USERPROFILE ?? '';
  for (const p of [join(home, '.moon', 'bin', 'moon'), '/opt/homebrew/bin/moon', '/usr/local/bin/moon']) {
    if (existsSync(p)) return p;
  }
  return null;
}

/** 属性对象 → CLI `k=v` 片段。字符串自动 JSON 引号，数字/布尔裸值。 */
export function encodeProps(props = {}) {
  const parts = [];
  for (const [k, v] of Object.entries(props)) {
    if (v === undefined || v === null) continue;
    parts.push(typeof v === 'string' ? `${k}=${JSON.stringify(v)}` : `${k}=${v}`);
  }
  return parts;
}

/**
 * MoonViz 引擎客户端。
 *
 * ```js
 * import { MoonViz } from '@moonviz/engine-sdk';
 * const engine = new MoonViz({ moonvizDir: '../moonviz' });
 * const r = await engine.run(['list-templates']);
 * ```
 */
export class MoonViz {
  /**
   * @param {object} [options]
   * @param {string} [options.moonvizDir]  引擎根目录（含 cli/moon.pkg）。默认自动向上查找。
   * @param {string} [options.moon]        moon 可执行文件路径。默认在 PATH 与 ~/.moon/bin 中查找。
   * @param {string} [options.target]      编译目标，默认 "native"。
   */
  constructor(options = {}) {
    this.moonvizDir = options.moonvizDir
      ? resolve(options.moonvizDir)
      : (process.env.MOONVIZ_DIR ? resolve(process.env.MOONVIZ_DIR) : defaultMoonvizDir());
    this.cliBin = options.cliBin ?? findPrebuiltCli();
    if (!this.cliBin) {
      // 回退模式：moon run 需要引擎目录（含 cli/moon.pkg）
      if (!this.moonvizDir || !existsSync(join(this.moonvizDir, 'cli'))) {
        throw new Error('找不到 MoonViz 引擎入口：安装 moonviz-bin-<platform> 平台包、传 moonvizDir/cliBin、或设置 MOONVIZ_DIR/MOONVIZ_CLI_BIN');
      }
    }
    this.moonPath = options.moon ?? findMoon() ?? 'moon';
    this.target = options.target ?? 'native';
  }

  /**
   * 执行一批 CLI 命令（同一个有状态会话），返回全部 JSON 行。
   * @param {string[]} commands
   * @returns {Promise<any[]>}
   */
  run(commands) {
    if (!Array.isArray(commands) || commands.length === 0) return Promise.resolve([]);
    return new Promise((resolveP, reject) => {
      // 预编译 CLI：完全自包含（仅链 libc），无 cwd 依赖；回退模式经 moon run。
      const child = this.cliBin
        ? spawn(this.cliBin, [], { stdio: ['pipe', 'pipe', 'pipe'] })
        : spawn(this.moonPath, ['run', '--target', this.target, 'cli'], {
            cwd: this.moonvizDir,
            stdio: ['pipe', 'pipe', 'pipe'],
          });
      let out = '', err = '';
      child.stdout.on('data', c => (out += c));
      child.stderr.on('data', c => (err += c));
      child.on('error', e => reject(new Error(`moon 启动失败（${e.message}）`)));
      child.on('close', code => {
        const results = [];
        for (const line of out.split('\n')) {
          const t = line.trim();
          if (t.startsWith('{') || t.startsWith('[')) {
            try { results.push(JSON.parse(t)); } catch { /* 非 JSON 行忽略 */ }
          }
        }
        if (results.length === 0 && code !== 0) {
          reject(new Error(`引擎无输出（exit ${code}）：${err.slice(0, 300)}`));
          return;
        }
        resolveP(results);
      });
      for (const cmd of commands) child.stdin.write(cmd + '\n');
      child.stdin.write('exit\n');
      child.stdin.end();
    });
  }

  /** 便捷：取结果数组中最后一个 JSON 对象。 */
  async last(commands) {
    const rs = await this.run(commands);
    return rs[rs.length - 1];
  }

  /** 渲染完整 MBT 源码（AgentGate 级重载）。返回 { ok, entry, revision, flows, artboards } */
  async render(mbt) {
    return this.last([`render-mbt-b64 ${b64(mbt)}`]);
  }

  /** 校验 MBT（不渲染）。返回 { ok, entry, revision, blockKinds } */
  async validate(mbt) {
    return this.last([`validate-mbt-b64 ${b64(mbt)}`]);
  }

  /** Human 操作：返回 { ok, mbt, artboards, flows, revision, debt } */
  async applyHumanOp(mbt, op) {
    return this.last([`apply-human-mbt-op-b64 ${b64(mbt)} ${b64(op)}`]);
  }

  /** Agent 操作：同一命令，Gate 为 AgentGate。 */
  async applyAgentOp(mbt, op) {
    return this.last([`apply-agent-mbt-op-b64 ${b64(mbt)} ${b64(op)}`]);
  }

  /** 高层：一次操作 + 校验渲染，一步拿到新 canonical MBT。 */
  async apply(mbt, op, gate = 'human') {
    const runner = gate === 'agent'
      ? (m, o) => this.applyAgentOp(m, o)
      : (m, o) => this.applyHumanOp(m, o);
    const r = await runner(mbt, op);
    if (!r.ok) throw new EngineError(r.error ?? 'apply_failed', r);
    return r;
  }

  /** 创建新画板。返回 { ok, artboard } */
  async create(name, width = 390, height = 844) {
    return this.last([`create ${name} ${width} ${height}`]);
  }
}

function b64(text) {
  return Buffer.from(text, 'utf8').toString('base64');
}
