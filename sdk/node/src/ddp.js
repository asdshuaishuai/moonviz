// DDP 编解码桥：Argon2id + XChaCha20-Poly1305（DDP1 加密）/ zstd + CRC32（DDP2 免密）。
// 实际加解密由引擎仓库的 Rust 工具 `ddp_codec` 完成（moonviz/ddp），本模块只负责
// 进程编排与 JSON 协议。协议：stdin JSON → stdout 单行 JSON。
//
//   加密：{"operation":"encrypt","mbt_b64":...,"password":...}        → {"ok":true,"ddp_b64":...}
//   解密：{"operation":"decrypt","ddp_b64":...,"password":...}        → {"ok":true,"mbt_b64":...}
//   免密：password 为空串时自动产出 DDP2 容器（无加密、有完整性校验）

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import process from 'node:process';

import { defaultMoonvizDir } from './session.js';

function findCodec(explicit) {
  if (explicit) {
    const p = resolve(explicit);
    if (existsSync(p)) return p;
  }
  if (process.env.MOONVIZ_DDP_HELPER && existsSync(process.env.MOONVIZ_DDP_HELPER)) {
    return process.env.MOONVIZ_DDP_HELPER;
  }
  const moonvizDir = process.env.MOONVIZ_DIR ?? defaultMoonvizDir() ?? process.cwd();
  for (const profile of ['debug', 'release']) {
    const p = join(moonvizDir, 'ddp', 'target', profile, 'ddp_codec');
    if (existsSync(p)) return p;
  }
  return null;
}

/** 运行一次 ddp_codec：stdin JSON → stdout JSON。 */
function runCodec(codecPath, payload) {
  return new Promise((resolve, reject) => {
    const child = spawn(codecPath, [], { stdio: ['pipe', 'pipe', 'pipe'] });
    let out = '', err = '';
    child.stdout.on('data', c => (out += c));
    child.stderr.on('data', c => (err += c));
    child.on('error', e => reject(new Error(`ddp_codec 启动失败：${e.message}`)));
    child.on('close', () => {
      try { resolve(JSON.parse(out)); }
      catch { reject(new Error(`ddp_codec 输出无效：${err.slice(0, 200) || out.slice(0, 200)}`)); }
    });
    child.stdin.write(JSON.stringify(payload));
    child.stdin.end();
  });
}

export const DDP = {
  /**
   * 加密 MBT 源码 → DDP 字节。
   * @param {string} mbt       完整 .mbt.md 源码
   * @param {string} password  密码；空串/未传 = 免密 DDP2（仅压缩+CRC32）
   * @param {object} [options] { codecPath?, moonvizDir? }
   * @returns {Promise<{bytes: Buffer, mode: 'DDP1'|'DDP2'}>}
   */
  async encrypt(mbt, password = '', options = {}) {
    const codec = options.codecPath
      ?? findCodec(options.moonvizDir)
      ?? (() => { throw new Error('找不到 ddp_codec：先构建 moonviz/ddp 或设置 MOONVIZ_DDP_HELPER'); })();
    const r = await runCodec(codec, {
      operation: 'encrypt',
      mbt_b64: Buffer.from(mbt, 'utf8').toString('base64'),
      password,
    });
    if (!r.ok) throw new Error(r.error ?? 'ddp_encrypt_failed');
    const bytes = Buffer.from(r.ddp_b64, 'base64');
    const magic = bytes.subarray(0, 4).toString();
    return { bytes, mode: magic };
  },

  /**
   * 解密 DDP 字节 → MBT 源码。DDP2 免密文件 password 传任意值均可。
   * @returns {Promise<{mbt: string, mode: 'DDP1'|'DDP2'}>}
   */
  async decrypt(bytes, password = '', options = {}) {
    const codec = options.codecPath
      ?? findCodec(options.moonvizDir)
      ?? (() => { throw new Error('找不到 ddp_codec：先构建 moonviz/ddp 或设置 MOONVIZ_DDP_HELPER'); })();
    const buf = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
    const r = await runCodec(codec, {
      operation: 'decrypt',
      ddp_b64: buf.toString('base64'),
      password,
    });
    if (!r.ok) throw new Error(r.error ?? 'ddp_decrypt_failed');
    return { mbt: Buffer.from(r.mbt_b64, 'base64').toString('utf8'), mode: r.magic ?? '' };
  },
};
