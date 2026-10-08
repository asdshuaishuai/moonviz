# SMART-UX-1.0：从原型设计引擎到 AI-Native Smart UX/UI 引擎

> 定位跃迁的正式规划。参照系：OpenAI GPT-6「Intelligent UI」（2026-10-07 发布，
> ChatGPT 直接以可交互 UI 作答——图表/表单/按钮/迷你工具，模型按请求编排
> 文本+视觉+交互元素；底座是 Apps SDK 与 apps-sdk-ui 设计系统）。
> 我们的差异化不是「复刻 chat 内嵌 UI」，而是在 **webview 内做到更高精度、
> 更优性能、更美的渲染**，并且让 UI 具备**数据交换能力**——活界面而非易逝产物。

---

## 0. 定位跃迁

| | 现在（原型/UI 设计引擎） | 升级后（Smart UX/UI 引擎） |
|---|---|---|
| 产出物 | 静态原型 + 导航流（可交互演示） | **数据驱动的活界面**（可嵌入宿主真实运行） |
| 渲染面 | SVG 导出（浏览器/编辑器） | webview 内 wasm 引擎直渲（高精度 DOM/混合模式） |
| 数据 | 死文本（设计期占位） | DataSchema 契约 + 绑定表达式（运行期真数据） |
| Agent 角色 | 画图（ops 摆放组件） | 生成活 UI（数据形态→版式→绑定，一句话出界面） |
| 事实源 | `.mbt.md`（不变） | `.mbt.md`（不变，扩展 schema/绑定段） |

**不变的根**：`.mbt.md` 唯一事实源、双门纪律（AgentGate/HumanGate）、
不崩谓词 P0–P4、纯 MoonBit。Smart UX 是在既有根上长出来的第三层能力。

---

## 1. 三支柱

### 支柱 A · Smart Rendering——webview 内高精度渲染（差异化主战场）

ChatGPT 的智能 UI 跑在 React iframe 里；我们跑在 **webview 内的纯 MoonBit wasm
引擎**上。这是精度与性能的代差机会：

- **渲染模式升级**：现有 SVG 直出之外，增加「精确 DOM 模式」——引擎输出
  语义化可交互 DOM（text/rect/button/input 映射真实元素），布局计算仍在
  MoonBit 侧（一套布局引擎两种后端，精度一致）；
- **精排细节**：字体真实度量接口（宿主注入 measure 回调，替代 em 估算）、
  亚像素对齐、CJK 标点悬挂/避头尾、滚动/裁剪/遮挡语义（scroll 容器语义化）；
- **交互原语**：组件状态（states 已有）→ 事件（tap/input/submit/scroll_end）→
  宿主桥（wasm 导出 `dispatch_event(json)` / `collect_actions()`）；
- **性能预算（GA 硬门）**：数据注入后增量更新 < 16ms（结构 diff，非全量重渲）、
  首帧可交互、wasm 包体不劣化超 10%。

### 支柱 B · Data Exchange——数据交换能力（活界面的本体）

- **DataSchema**：`.mbt.md` frontmatter 新增 `data:` 段——类型化字段契约
  （JSON Schema 子集：string/number/boolean/array/object + 必填/枚举）；
- **绑定表达式**：节点属性支持 `{{path}}` 插值（`text={{user.name}}`、
  `fill={{theme.primary}}`），一期只读、二期表单双向；
- **数据面 API**（wasm 导出面扩展）：
  - `set_data(path, json)` → 引擎重解析绑定 → **精确更新受影响节点**（结构 diff）；
  - `collect_actions()` → 宿主取回 UI 事件（表单值、点击意图、提交载荷）；
  - `data_schema()` → 宿主获得该 UI 期望的数据契约（Agent/宿主据此喂数据）；
- **交换协议**：宿主 ⇄ 引擎全程结构化 JSON（复用既有 canonical JSON 底座），
  数据进、事件出、动作回——UI 成为宿主的一等可编程表面。

### 支柱 C · Smart Generation——AI 原生生成的跃迁

- **语义级 op 扩展**：在既有 27 ops 之上新增 `bind`（属性绑定）、
  `schema`（声明 DataSchema）、`compose`（语义组合：列表/详情/表单/看板意图）；
- **意图模板**：给引擎一份 JSON 数据样本，Agent 经工具环推断版式
  （table/list/detail/dashboard）+ 引擎布局约束兜底——**数据长出界面**；
- **与 ChatGPT 对位**：Intelligent UI 的产物是模型一次性输出的易逝界面；
  MoonViz 的 smart UI 是**可回写、可 diff、可协作、可时间旅行的文档资产**
  ——生成只是生命周期的第一步。

---

## 2. 与 RENDER-1.0 的关系

RENDER-1.0（渲染精致化）整体并入本规划为 **P0 前置**：精致感是 smart UI 的地基。
- 已落地 ✅：PaintSpec 渐变、阴影 e0–e5、宽度感知换行、字号自适应（fit）、
  placeholder 独立色、图标系统 25 枚、组件自适应预设；
- 照旧推进：R2 图标扩至 ~120 与组件打通、R3 组件审计、R4 主题×组件回归快照；
- 验收口径并入 smart UI：精致度基准页 = smart UI 基准页（含数据态/空态/加载态）。

---

## 3. 里程碑（M-S 系列）

- **M-S1 · smart 基座**：DataSchema + `{{绑定}}` 表达式 + `set_data`/`data_schema`
  导出面 + 三个演示组件（list/detail/form）——验收：**一份 JSON 数据长出一个界面，
  换数据界面变**。
- **M-S2 · 交互闭环**：`dispatch_event`/`collect_actions` + 表单双向绑定 +
  结构 diff 增量渲染——验收：表单填写→collect_actions 拿到类型化载荷；
  16ms 预算测试进 CI。
- **M-S3 · webview 宿主面**：鸿蒙 webview / 移动 webview 嵌入样例
  （复用 deepdesign-studio harmonyos-port 与 ddpView 经验）+ 字体度量宿主回调 +
  首帧/内存预算——验收：真机 webview 内高精度渲染 demo。
- **M-S4 · Agent 智能生成**：意图模板 + 工具环升级（数据→UI）+
  playground AI 面板对接（BYOK 面板已有）——验收：对话式「用这份数据做个看板」
  出活界面。
- **GA 门**（对齐既有纪律）：不崩谓词覆盖 smart 语境（绑定失败不崩、schema
  不匹配降级显示）、canonical 往返零破坏、三目标构建、性能预算达标、
  纯 UI 文档（无 schema）行为逐字节不变。

---

## 4. 工程纪律（沿用，无新增豁免）

- NodeStyle/新字段扩展走 overlay 先例流程：canonical 条件写出 + 解析回读 +
  字典/help/SKILL 同步 + 契约测试；
- **兼容红线**：绑定与 schema 是纯增量——既有 `.mbt.md` 不改一字仍逐字节
  渲染一致；未知 frontmatter 段落按 issue #20 通道透传不丢弃；
- wasm classic 保持标准 MVP、宿主中立、零 import（红线不变）；
- 每个里程碑交付契约测试 + 演示文档（`examples/smart-*.mbt.md`）+ 字典同步。

---

## 5. 风险与对策

| 风险 | 对策 |
|---|---|
| DOM 模式与 SVG 模式精度漂移 | 同一布局引擎两种后端；跨后端像素快照 diff 测试 |
| 绑定表达式膨胀成脚本语言 | 一期只做路径插值 + 管道（大小写/格式化），表达式永不为图灵完备 |
| 增量渲染引入回归 | 结构 diff 以「输出等价性」测试锚定：set_data 前后全量渲染对比受影响子树 |
| webview 字体度量宿主差异 | 度量回调接口化，缺省回退 em 估算（现有路径，永不崩） |
| 范围蔓延 | M-S1 先立「数据长出界面」最小闭环；GA 门不达标不进 M-S4 |
