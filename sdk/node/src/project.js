// 高层项目 API：把 CLI 原子命令编排为一次有状态构建会话。
// 典型用法：
//
//   const engine = new MoonViz({ moonvizDir: '../moonviz' });
//   const project = new Project(engine);
//   project.template('login', 't_login', 390, 844);
//   project.template('dashboard', 't_home', 390, 844);
//   project.flow('t_login', 't_home', 'login_btn');
//   const mbt = await project.exportHuman();
//
// 每次导出都从同一 CLI 会话（同一 Project 内存态）产出 canonical `.mbt.md`。

import { encodeProps } from './session.js';

export class Project {
  /** @param {import('./session.js').MoonViz} engine */
  constructor(engine) {
    this.engine = engine;
    this.commands = [];   // 累积的 CLI 命令草稿
  }

  get size() { return this.commands.length; }

  // ---- 结构 ----

  template(templateId, name = templateId, width = 390, height = 844) {
    this.commands.push(`template ${templateId} ${name} ${width} ${height}`);
    return this;
  }

  create(name, width = 390, height = 844) {
    this.commands.push(`create ${name} ${width} ${height}`);
    return this;
  }

  duplicate(src, newName) {
    this.commands.push(`duplicate ${src} ${newName}`);
    return this;
  }

  /** 删除画板（至少保留一个；由引擎校验）。 */
  deleteArtboard(id) {
    this.commands.push(`delete-artboard ${id}`);
    return this;
  }

  // ---- 元素 ----

  /** 更新节点属性：props 为 { text, fill, x, y, w, h, radius, opacity, tracking, ... }。 */
  update(artboard, node, props) {
    this.commands.push(`update ${artboard} ${node} ${encodeProps(props).join(' ')}`);
    return this;
  }

  move(artboard, node, x, y) {
    this.commands.push(`move ${artboard} ${node} ${x} ${y}`);
    return this;
  }

  /** 翻转：h / v / both / none。 */
  flip(artboard, node, mode = 'h') {
    this.commands.push(`flip ${artboard} ${node} ${mode}`);
    return this;
  }

  /** Z 序：front / back / up / down。 */
  reorder(artboard, node, where = 'front') {
    this.commands.push(`reorder ${artboard} ${node} ${where}`);
    return this;
  }

  /** 复制节点（+dx +dy 偏移）。 */
  copy(artboard, node, newId, dx = 24, dy = 24) {
    this.commands.push(`copy ${artboard} ${node} ${newId} ${dx} ${dy}`);
    return this;
  }

  // ---- 交互流 ----

  /** 交互流：点击 from 画板的 triggerNode → 跳转 to 画板。 */
  flow(from, to, triggerNode) {
    this.commands.push(`flow ${from} ${to} ${triggerNode}`);
    return this;
  }

  // ---- 导出 ----

  /** 导出 canonical `.mbt.md`（HumanGate：结构违规硬阻断）。返回导出的完整文本。 */
  async exportHuman() {
    this.commands.push('export-mbt-human');
    const rs = await this.engine.run(this.commands);
    this.commands = [];   // 会话状态已随导出固定
    const out = rs[rs.length - 1];
    if (!out?.ok) throw new Error(out?.error ?? 'export_failed');
    return out.mbt;
  }

  /** 切换全局主题（角色重着色，可逆；frontmatter theme: 持久化）。 */
  theme(name) { this.cmds.push(`theme ${name}`); return this; }

  /** 覆盖单个颜色令牌（重着色旧值；frontmatter tokens: 持久化）。 */
  token(name, value) { this.cmds.push(`token ${name} ${value}`); return this; }

  /** 绑定交互：trigger × action_spec（写入 ⚡ 标记）。 */
  interact(artboard, node, trigger, actionSpec) {
    this.cmds.push(`interact ${artboard} ${node} ${trigger} ${actionSpec}`);
    return this;
  }

  /** 定义组件状态补丁（fill/text_color/stroke/text/radius/font_size）。 */
  state(artboard, node, stateName, kvs = {}) {
    const args = Object.entries(kvs).map(([k, v]) => `${k}=${v}`).join(' ');
    this.cmds.push(`state ${artboard} ${node} ${stateName} ${args}`.trim());
    return this;
  }

  /** 设置组件当前状态（[cur:] 标记持久化；toggle=true 在默认态间切换）。 */
  setState(node, stateName, toggle = false) {
    this.cmds.push(`set-state ${node} ${stateName}${toggle ? ' toggle' : ''}`);
    return this;
  }

  /** 导出自包含可交互 HTML 原型。 */
  async exportHtml() {
    const out = await this.engine.last([...this.cmds, 'export-html']);
    if (!out?.ok) throw new Error(out?.error ?? 'export_failed');
    return out.html;
  }
}

/**
 * 便捷工厂：执行构建脚本并返回 canonical `.mbt.md`。
 *
 *   const mbt = await build(engine, p => {
 *     p.template('login', 't_login', 390, 844);
 *     p.template('dashboard', 't_home', 390, 844);
 *     p.flow('t_login', 't_home', 'login_btn');
 *     p.update('t_login', 'welcome_title', { text: 'Welcome' });
 *   });
 */
export async function build(engine, recipe) {
  const p = new Project(engine);
  recipe(p);
  return p.exportHuman();
}
