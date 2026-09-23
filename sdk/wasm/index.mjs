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
     * 预设组件库清单（8 组件 × 22 变体）。
     * @returns {Array<{id:string,kind:string,category:string,variants:string[]}>}
     */
    listComponents() {
      return JSON.parse(exports.list_components());
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

    /** op 面字典（26 条 mutating op：op/usage/category/gates）。 */
    listOps() {
      return JSON.parse(exports.list_ops());
    },

    /** 主题清单（name/display_name/is_dark）。 */
    listThemes() {
      return JSON.parse(exports.list_themes());
    },

    /** 默认设计令牌清单（colors/spacing/radii/typography）。 */
    listTokens() {
      return JSON.parse(exports.list_tokens());
    },

    // ── 会话 API（i32 句柄；对齐 CLI/MCP 会话型能力）──

    /** 打开有状态会话，返回句柄（<0 = 错误）。 */
    sessionOpen(mbt) {
      return exports.session_open(mbt);
    },

    /** 应用 mutating op（gate: 'agent' | 'human'）。返回 { ok, mbt }。 */
    sessionApply(handle, op, gate = 'human') {
      const fn = gate === 'agent' ? exports.session_apply_agent : exports.session_apply_human;
      return JSON.parse(fn(handle, op));
    },

    /** 画板级 SVG 导出。 */
    sessionExportSvg(handle, artboard) {
      return JSON.parse(exports.session_export_svg(handle, artboard));
    },

    /** 设计 Lint。 */
    sessionLint(handle, artboard) {
      return JSON.parse(exports.session_lint(handle, artboard));
    },

    /** AI 设计批评。 */
    sessionCritique(handle, artboard) {
      return JSON.parse(exports.session_critique(handle, artboard));
    },

    /** 交互清单。 */
    sessionInteractions(handle, artboard) {
      return JSON.parse(exports.session_interactions(handle, artboard));
    },

    /** 原型运行时 tap 命中。x/y 为画板坐标。 */
    sessionTap(handle, artboard, x, y) {
      return JSON.parse(exports.session_tap(handle, artboard, x, y));
    },

    /** 关闭会话。 */
    sessionClose(handle) {
      return exports.session_close(handle);
    },

    /** 当前活跃会话数（泄漏观测，issue #1）。 */
    sessionCount() {
      return exports.session_count();
    },

    /** 从 project JSON 快照打开会话（save→open 回灌，issue #4B）。 */
    sessionOpenProjectJson(projectJson) {
      return exports.session_open_project_json(projectJson);
    },

    /** 会话 JSON 快照（与 sessionOpenProjectJson 配对）。 */
    sessionSave(handle) {
      return JSON.parse(exports.session_save(handle));
    },

    /** 节点查询（统一信封 {ok, data}）。 */
    sessionQueryNodes(handle, artboard) {
      return JSON.parse(exports.session_query_nodes(handle, artboard));
    },

    /** 其余 session_* 以 raw 导出直用（spec/constrain/infer/用户组件…）。 */
    raw: exports,
  };
}
