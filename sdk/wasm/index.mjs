// WASM 引擎加载器：在浏览器与 Node（≥22）宿主中实例化 moonviz.wasm。
//
// 引擎以 wasm-gc 编译并启用 JS String Builtins——MoonBit String 与宿主字符串
// 直接互通，无需跨边界编解码。宿主需支持：
//   - WebAssembly GC（Chrome 119+ / Node 22+ / Firefox 120+ / Safari 18.2+）
//   - js-string builtins 编译选项（Chrome/Node 已默认支持）

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const WASM_PATH = join(HERE, 'dist', 'moonviz.wasm');

/** 宿主字节来源：Node 读文件；浏览器由调用方传入 Response/ArrayBuffer。 */
async function defaultBytes() {
  return readFile(WASM_PATH);
}

async function instantiate(bytes) {
  const module = new WebAssembly.Module(bytes, {
    builtins: ['js-string'],
    importedStringConstants: '_',
  });
  try {
    return new WebAssembly.Instance(module, {}).exports;
  } catch (e) {
    // imported string constants 需要 V8 较新版本：Node 24+ / Chrome 119+ /
    // Firefox 120+ / Safari 18.2+。Node 22 的 V8 尚未默认启用。
    if (e.message && e.message.includes('module "_"')) {
      throw new Error(
        'This runtime lacks JS-string builtins support (imported string constants). ' +
          'Use Node 24+ or a current browser (Chrome 119+, Firefox 120+, Safari 18.2+).',
      );
    }
    throw e;
  }
}

/**
 * 创建 WASM 引擎实例。
 *
 * ```js
 * import { createEngine } from 'moonviz-engine-wasm';
 * const engine = await createEngine();          // Node：自动读包内 wasm
 * const view = engine.render(mbt);              // 同步！无子进程、无工具链
 * ```
 *
 * 浏览器：`createEngine(await fetch('/moonviz.wasm').then(r => r.arrayBuffer()))`
 *
 * @param {BufferSource|Response} [source]
 */
export async function createEngine(source) {
  let bytes;
  if (source instanceof Response) bytes = await source.arrayBuffer();
  else if (source) bytes = source;
  else bytes = await defaultBytes();
  const exports = await instantiate(bytes);

  return {
    /** 引擎版本信息（JSON 字符串）。 */
    version: () => JSON.parse(exports.version_info()),

    /**
     * 从 `.mbt.md` 源码完整重建视觉（AgentGate 级重载）。
     * @param {string} mbt 完整 .mbt.md 源码
     * @returns {{ok:boolean, entry?:string, flows?:Array, artboards?:Array, error?:string}}
     *   artboards 每项含 { id, width, height, svg, nodes }
     */
    render(mbt) {
      return JSON.parse(exports.render_mbt(mbt));
    },

    /**
     * 校验 `.mbt.md`（不渲染）。
     * @returns {{ok:boolean, entry?:string, revision?:number, blockKinds?:object, error?:string}}
     */
    validate(mbt) {
      return JSON.parse(exports.validate_mbt(mbt));
    },

    /**
     * 导出可交互 HTML 原型（单文件自包含）：节点级 flow/⚡ 词汇表绑定、
     * 组件状态 CSS 变体、导航栈与 toast。
     * @param {string} mbt 完整 .mbt.md 源码
     * @returns {{ok:boolean, html?:string, error?:string}}
     */
    exportHtml(mbt) {
      return JSON.parse(exports.export_html(mbt));
    },

    /** 原始 wasm 导出（高级用法）。 */
    raw: exports,
  };
}
