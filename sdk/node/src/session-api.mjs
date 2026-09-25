// 会话层（session API）：对齐 wasm SDK 的 session 形态（open/apply/lint/…/count）。
//
// 实现说明：底层 CLI 是批处理进程（run() 一次性 spawn，stdout 块缓冲、
// 进程退出时才 flush——常驻交互式管道拿不到逐条响应）。因此 Session 采用
// **命令历史重放**：每次 exec 以 [seed, ...history, cmd] 起一个进程，
// 取最后一条 JSON 作为响应，再把 cmd 追加进 history。调用方看到的是
// 有状态会话（open → apply → lint → … → close），语义与 wasm 的 i32
// 句柄对齐（P0-3：Node SDK 会话封装）。

import { MoonViz, EngineError } from './session.js';

/**
 * 有状态设计会话（命令历史重放实现）。
 *
 * ```js
 * import { MoonViz, Session } from '@moonviz/engine-sdk';
 * const engine = new MoonViz();
 * const s = await Session.open(engine, 'template login t_login 390 844');
 * await s.apply('update t_login welcome_title text=你好');
 * s.lint('t_login');          // → 设计 Lint JSON
 * await s.close();
 * ```
 */
export class Session {
  /**
   * @param {import('./session.js').MoonViz} engine
   * @param {string[]} [history] 初始命令历史（内部使用）
   */
  constructor(engine, history = []) {
    this.engine = engine;
    this.history = [...history];
    this.closed = false;
  }

  /**
   * 打开会话并用初始命令播种（通常是 template/create）。
   * @param {import('./session.js').MoonViz} engine
   * @param {string} [seedCommand]
   * @returns {Promise<Session>}
   */
  static async open(engine, seedCommand) {
    const s = new Session(engine);
    if (seedCommand) await s.exec(seedCommand);
    return s;
  }

  /**
   * 执行一条 CLI 命令，返回解析后的 JSON（最后一条响应）。
   * @param {string} command
   * @returns {Promise<any>}
   */
  async exec(command) {
    if (this.closed) throw new EngineError('session_closed');
    if (!command || !command.trim()) throw new Error('exec(command)：command 不能为空');
    // 命令注入防护：换行分帧协议下，含换行的命令会被拆成多条执行
    if (/[\r\n]/.test(command)) {
      throw new EngineError('command_contains_newline', { command });
    }
    const results = await this.engine.run([...this.history, command]);
    if (results.length !== this.history.length + 1) {
      // 响应条数与命令数不符：信封非法或引擎异常，归因不可靠
      throw new EngineError('response_count_mismatch', { expected: this.history.length + 1, got: results.length });
    }
    const last = results[results.length - 1];
    // 错误判别：{ok:false} 或无 ok 但带 error 字段（collab/history 等错误信封）
    const failed = last && (last.ok === false || (last.ok === undefined && typeof last.error === 'string'));
    if (failed) {
      // 失败命令不入 history：CLI 对失败命令不改状态，重放时跳过即安全
      throw new EngineError(last.error || 'command_failed', last);
    }
    this.history.push(command);
    return last;
  }

  /** 应用一条 mutating op（与 wasm sessionApply 同一语义；HumanGate 放行视觉债）。 */
  apply(op) { return this.exec(op); }

  /** 设计 Lint（与 wasm sessionLint 对齐）。 */
  lint(artboard) { return this.exec(`lint ${artboard}`); }

  /** AI 设计批评。 */
  critique(artboard) { return this.exec(`critique ${artboard}`); }

  /** 自动修复。 */
  autoFix(artboard) { return this.exec(`fix ${artboard}`); }

  /** 自然语言布局意图（居中 | 垂直排列 | 等宽 | 间距 N …；与 wasm sessionConstrain 同语义）。 */
  constrain(artboard, intent) { return this.exec(`constrain ${artboard} ${intent}`); }

  /** 交互清单。 */
  interactions(artboard) { return this.exec(`interactions ${artboard}`); }

  /** 组件状态清单。 */
  states(artboard) { return this.exec(`states ${artboard}`); }

  /** 节点查询。 */
  queryNodes(artboard) { return this.exec(`query ${artboard}`); }

  /** 导航流清单。 */
  flows() { return this.exec('flows'); }

  /** 设计标注 Spec。 */
  spec(artboard) { return this.exec(`spec ${artboard}`); }

  /** 原型测试脚本（protest）。 */
  protest(artboard, script) { return this.exec(`protest ${artboard} ${script}`); }

  /** 多 Agent 合并（collab-merge）。 */
  collabMerge(spec) { return this.exec(`collab-merge ${spec}`); }

  /** 动画 CSS 生成。 */
  animationCss(nodeId, preset) { return this.exec(`anim-css ${nodeId} ${preset}`); }

  /** 版本历史子命令（init/commit/log/undo/redo/checkout/diff）。 */
  history(...args) { return this.exec(['history', ...args].join(' ')); }

  /** 导出 canonical MBT（当前会话状态）。 */
  exportMbt() { return this.exec('export-mbt-human'); }

  /** 当前会话命令数（调试/观测用）。 */
  get depth() { return this.history.length; }

  /** 关闭会话（重放模型下无进程可关，仅标记状态）。 */
  async close() { this.closed = true; }
}

export { MoonViz, EngineError };
