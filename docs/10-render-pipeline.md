# 10 — 绘制方案与渲染管线（完整技术说明）

> 本文是 MoonViz 引擎"如何把一份 `.mbt.md` 变成像素"的完整技术文档：从声明解析、场景图、布局求解、谓词验证到三个渲染后端（SVG / PNG / 终端 ANSI）的全部实现细节，以及支撑它们的技术栈与二进制分发策略。
>
> 对应源码：`decl/mbt.mbt` · `core/{node,layout,predicates,policy,svg,runtime}.mbt` · `playground/{render2,png,deflate,canvas}.mbt`

---

## 0. 一次渲染的完整数据流

```
.mbt.md（MoonBit literate 源码，唯一事实源）
   │  ① 声明加载（decl/mbt.mbt）
   ▼
MbtProject ──► Document（场景图：节点树 + 样式 + 交互流）
   │  ② 布局求解（core/layout.mbt，两遍法）
   ▼
SolvedLayout（每个节点的画布绝对矩形 Rect + 求解失败清单）
   │  ③ 谓词验证（core/predicates.mbt，P0–P4）+ 双 Gate 合并决策（core/policy.mbt）
   ▼
已验收的 (Document, SolvedLayout)
   │  ④ 后端渲染（三条独立路径）
   ├──► SVG 字符串（core/svg.mbt）              —— 矢量，Studio/查看器/导出
   ├──► PNG 字节流（playground/render2+png+deflate）—— 像素，含抗锯齿与压缩
   └──► 终端 ANSI 画布（playground/canvas.mbt）   —— REPL/CLI 内预览
   ▲
   └── （任意宿主后端）RenderPlan 显示列表（core/runtime.mbt）
```

**不变量**：渲染层不承担正确性责任——任何进入渲染的文档都已通过（或被人类路线明确接受为）谓词检查；渲染器永远只做"把已求解的矩形画出来"。反过来，任何视觉输出都是对源文件这一份事实的**完整重建**，不存在增量缓存或旁路状态。

---

## 1. 阶段 ①：声明加载（decl/mbt.mbt）

`.mbt.md` 遵循 MoonBit literate 源码规则：` ```mbt ` 块参与编译，`mbt check` / `mbt nocheck` / `moonbit` 块用于展示。MoonViz 在此之上约定：

- 每个画板一个 `<!-- moonviz:artboard <id> -->` 标记的 `mbt` 块，块内是**声明式 API 调用**（`@decl.prototype(...)`、`page.add(@decl.generic_node(...))`）；
- YAML frontmatter 携带项目元信息：`entry`（入口画板）、`artboards` 列表、`flows`（交互流表：`from / to / trigger`）、`revision`。

加载流程：

1. **块扫描**（`scan_mbt`）——把 markdown 切分为带类型的块序列，识别 visual 块并统计 `blockKinds`（`mbt / mbt_check / mbt_nocheck / moonbit`）；
2. **声明解析**——对每个 visual 块解析公开的 `@decl` 调用，构造 `Prototype`（画板）与节点声明；只接受引擎支持的公开声明，任何私有/未知语法报**行级错误**而不是静默丢弃；
3. **装配**（`load_mbt_project`）——frontmatter + 各画板声明 + 流表 → `MbtProject`（含 `project: Project` 场景图容器与 `document` 元信息）。

往返保证：`MbtProject::to_mbt()` 能把内存态重新序列化为 canonical `.mbt.md`——解析与序列化是同一文法的一对实现，这是"human 与 Agent 都回写同一源"的技术基础。

## 2. 阶段 ②：场景图与布局求解

### 2.1 场景图模型（core/node.mbt）

- `Document`：根节点 + 节点表（id → `Node`）+ 交互流；
- `Node`：结构字段（id、kind、容器子序）+ `Style`（fill/stroke/radius/opacity/font_size/text_color/font_weight/shadow/rotate/blur/blend/line_height/tracking/flip/constraint…）；
- **尺寸规格 `SizeSpec`**：`Fixed(Double)` 定值 / `Fill` 占满可用主轴空间 / `Hug` 包裹内容（v1 仅 Text 支持 Hug）；
- **位置规格 `PosSpec`**：`Fixed(Double)` 定值（相对父容器）；
- **对齐**：主轴对齐决定无 Fill 子项时剩余空间的分配。

### 2.2 两遍法求解器（core/layout.mbt）

```
solve(doc) → SolvedLayout { rects: Map[id, Rect], failures: [SolveFailure] }
```

- **第一遍（尺寸）**：自根向下递归——容器先按自身规格确定尺寸，再把可用主轴空间分配给子项（Fill 展开吸满、Hug 先测内容、Fixed 取定值）；
- **第二遍（位置）**：按子序与对齐规则落位，输出**画布绝对坐标矩形**；
- **失败 ≠ 崩溃**：求解器永远产出有限矩形。解不开的约束（根缺失、引用不存在节点、容器负剩余空间 `NegativeResidual`、不支持规格组合 `UnsupportedSpec`）记入 `failures`，交由谓词层定级。这个接口刻意稳定——未来可以把实现替换为 Cassowary / SRT 求解器而不影响验证协议与渲染层。

### 2.3 谓词验证与双 Gate（core/predicates.mbt + policy.mbt）

布局完成后，每个画板跑 P0–P4 不崩谓词（详见 [04-layout-and-predicates.md](04-layout-and-predicates.md)）。合并门槛由 `Gate` 决定：

| Gate | 结构谓词 | 视觉谓词 |
|---|---|---|
| HumanGate（`export-mbt-human`） | 硬阻断 | 软提示 → 记为**视觉债 debt** |
| AgentGate（`export-mbt-agent` / `render-mbt-b64`） | 硬阻断 | 硬阻断 |

`decide()` 返回 `Allow(violations)`（携带债务）或 `Reject(blocking)`（携带阻断清单，含画板 id + 谓词名 + 详情）。

## 3. 阶段 ④：三个渲染后端

三个后端消费同一份 `(Document, SolvedLayout)`，彼此独立、可各自替换。

### 3.1 SVG 后端（core/svg.mbt）——矢量主路径

`render_svg(doc)` 的产出结构：

1. `<svg>` 根，`width/height/viewBox` 取根矩形（即画布尺寸），浅底衬色；
2. `<style>` 内嵌**系统字体栈**：`-apple-system,'SF Pro Text','PingFang SC','Segoe UI',Roboto,sans-serif`——不嵌入字体文件，宿主平台字体直接生效；
3. `<defs>` 渐变：paint 语法 `linear:#a:#b@deg` / `radial:#a:#b` 在 `collect_gradients` 中收集展开为 `<linearGradient>/<radialGradient>`，节点以 `url(#id)` 引用；
4. `<defs>` **elevation 阴影令牌**：`e1/e2/e3` 三档 `feDropShadow`（dy 1/4/14，stdDeviation 2/10/28，不透明度 0.07/0.10/0.16）——Material 风格高度系统，节点按 shadow 令牌引用；
5. 节点树序 emit：容器先画、子节点覆盖；圆角矩形、文本（单行居中 baseline = `y + (h + font_size*0.7)/2`；多行按 `line_height * font_size` 行距推进首 baseline `y + font_size`，字距 `letter-spacing = tracking * font_size`）、描边、透明度、旋转/模糊/混合模式按样式映射 SVG 属性；文本经 `xml_escape`。

SVG 是 Studio 画布、ddpView 查看器、`export-svg`、WASM SDK（`render_mbt`）的共同输出格式。

### 3.2 像素 PNG 后端（playground/render2.mbt + png.mbt + deflate.mbt）

完全自研的软光栅化路径，零图像库依赖：

```
Document → solve() → 高分辨率 RGBA 帧缓冲（2x 超采样）
        → 盒式 downscale（抗锯齿）→ DEFLATE 压缩 → PNG 字节流
```

- **帧缓冲 `HiResBuf`**：`FixedArray[Int]`（ARGB），尺寸 = 输出尺寸 × 超采样率（固定 ss=2），即像素密度 2 的内部画布；
- **几何扫描**：圆角矩形扫描线填充（含每角半径）、描边；容器树序绘制、子覆盖父；
- **抗锯齿**：在 2x 缓冲上光栅化，再 2×2 盒式滤波 downscale——边缘平滑、圆角柔和；
- **文字**：内置 5×7 位图字体，支持节点文本标注（终端外预览无字体依赖的关键）；
- **压缩 `deflate.mbt`**：纯 MoonBit 的 DEFLATE fixed-Huffman 实现（vendored from mizchi/zlib，Apache-2.0），`png_encode_deflate` 输出的 PNG 比 store-mode 小 **5–20 倍**；
- **封装 `png.mbt`**：PNG 容器（IHDR/IDAT/IEND + CRC32），产物为可直接落盘/内嵌 data URI 的字节流。

该后端证明引擎具备脱离浏览器/系统图形栈的完整绘制能力（终端 `png` 命令、CI 出图、无头快照）。

### 3.3 终端 ANSI 后端（playground/canvas.mbt）

REPL / CLI 内的即时预览，同样纯 MoonBit（wasm-gc / native / js 三目标可编译）：

- **`Camera`**：视口平移/缩放（`pan_x/pan_y/zoom`），维护屏幕字符坐标 ↔ 世界像素坐标变换（行高 = 列宽 2 倍）；
- **`ScreenBuf`**：字符栅格，每格 = 字符 + ANSI 真彩前缀（24-bit SGR）；
- **`draw_document`**：树序把 Document 画进栅格（容器先画、子覆盖）；
- **`pick_at`**：屏幕 → 世界 → 最上层节点命中，支撑终端画布里的拖拽编辑（拖拽坐标经相机逆变换后走 `handle_human` 会话协议）。

### 3.4 RenderPlan：后端无关显示列表（core/runtime.mbt）

嵌入式运行时把渲染进一步抽象为**显示列表**：

```
MoonVizRT::create(project)   // 运行时实例
rt.handle_event(event)       // Tap/LongPress/Swipe/Key/Focus/Blur → 状态变更
rt.render_plan()             // → RenderPlan（显示列表）
rt.hot_reload(decl)          // 更新声明文本，保留运行时状态
```

任何后端（HTML Canvas / Skia / SVG / 终端 / OpenGL）都能消费同一份 RenderPlan——宿主编辑器接入时不必理解场景图，只需实现一个显示列表解释器。事件与渲染分离也让交互流（tap 跳转画板）在任意宿主一致复现。

## 4. 交互流渲染

frontmatter `flows` 表 + `flow` 命令维护的边（`from / to / trigger`，trigger 形如 `tap:<node_id>`）在渲染时叠加为**可点击区域**：

- SVG 输出中触发节点带 `data-flow-trigger` 语义（Studio/ddpView 据此高亮并绑定跳转）；
- 终端画布中 `pick_at` 命中触发节点即执行画板切换；
- MCP `render_mbt` 返回结构化 `flows` 数组，宿主自行决定可视化方式。

原型不是静态图：导航栈（`core/interaction.mbt`）维护完整的 Trigger/Action/Transition 语义。

---

## 5. 技术栈总览

| 层 | 技术 | 依赖外部库 | 说明 |
|---|---|---|---|
| 引擎内核（core/ + decl/） | **100% MoonBit** | 仅 `moonbitlang/core` 标准库 | 场景图/布局/谓词/补丁/组件/模板/交互/智能 |
| SVG 渲染 | MoonBit 字符串构建 | 无 | 系统字体栈 + SVG 滤镜，零依赖 |
| PNG 光栅化 | MoonBit 自研 | 无 | 2x SSAA + 圆角扫描 + 5×7 位图字体 |
| DEFLATE | MoonBit（vendored mizchi/zlib, Apache-2.0） | 无 | fixed-Huffman，5–20× 压缩 |
| 终端画布 | MoonBit | 无 | ANSI 真彩 + Camera 变换 |
| CLI / MCP | MoonBit | 无 | native 二进制或 wasm-gc |
| WASM 边界 | MoonBit → wasm-gc | 无 | JS String Builtins 直通 |
| DDP 加密 | **Rust**（ddp/，独立进程） | argon2 / chacha20poly1305 / zstd / crc32 | stdin JSON → stdout JSON，与引擎解耦 |
| Node SDK | JavaScript（ESM，零依赖） | 无 | 纯传输/编排层 |

**语言占比**：引擎 + 渲染 + 协议 = 100% MoonBit；DDP 编解码 = Rust（可独立替换）；npm 启动器 = 极薄 JS（仅二进制选择与 spawn）。渲染路径上没有任何 JavaScript。

## 6. 二进制分发与 MoonBit 工具链风险管理

### 6.1 事实：预编译二进制完全自包含

`moon build --release --target native <pkg>` 的产物（`cli.exe` 1.26 MB / `mcp.exe` 1.10 MB）经 `otool -L` 验证**仅链接系统 libc**（macOS: `/usr/lib/libSystem.B.dylib`；Linux: glibc），MoonBit runtime 已静态链入。把二进制复制到无 moon、无引擎源码的目录直接执行，`list-templates` / JSON-RPC `initialize` 均正常。

**结论：moon 工具链只在"编译时"需要；所有终端用户路径（npx moonviz-mcp、预编译 CLI、WASM SDK）都零工具链依赖。**

### 6.2 分发矩阵

| 消费者 | 依赖 moon？ | 依赖引擎源码？ | 通道 |
|---|---|---|---|
| MCP 客户端 | ✗ | 仅 MOONVIZ_DIR 场景的源侧工具 | `npx moonviz-mcp`（平台二进制） |
| Node SDK 调用方 | ✗（配 `MOONVIZ_CLI_BIN`） | ✗ | `moonviz-bin-*` 平台包内 CLI 二进制 |
| 浏览器 / Edge | ✗ | ✗ | `moonviz-engine-wasm`（wasm-gc 产物） |
| 引擎开发者 | ✓ | ✓ | `moon run` / `moon test` |

### 6.3 版本锁定与破坏性迭代对策

MoonBit 语言仍在快速演进，确实存在 minor 版本间行为差异的现实风险。对策按层次：

1. **消费者层（最有效）**：预编译二进制与 WASM 产物一经发布即是**冻结快照**——下游永远运行发布时的编译结果，工具链后续任何破坏性变更都不影响已分发产物。这是把"语言不确定性"隔离在构建时的根本手段。
2. **构建层 pin**：`moon.mod.json` 声明模块版本；CI（`.github/workflows/binaries.yml`）安装固定版本的 moon 工具链——升级工具链是**显式 PR 行为**，配套 `moon test`（142 项）与 CLI/MCP 冒烟测试，不匹配直接挡在 CI。
3. **本地层**：`moon upgrade` 可安装/回滚指定版本；`_build/` 全量产物可随时用 `moon build --release --target native all` 重建并比对。
4. **架构层兜底**：即使求解器/标准库发生破坏性迭代，`SolvedLayout`、`GateDecision`、`RenderPlan` 等引擎对外协议刻意保持稳定（求解器甚至预留了替换为 Cassowary 的接口）——协议稳定性不依赖语言版本。
5. **逃生门**：DDP 编解码已示范了"非 MoonBit 组件独立进程化"的路线；极端情况下任何组件都可按此模式替换而不动事实源格式。

---

## 7. 相关文档

- [01-architecture.md](01-architecture.md) 分层架构
- [02-mbtmd-format.md](02-mbtmd-format.md) `.mbt.md` 文法与声明 DSL
- [03-scene-graph.md](03-scene-graph.md) 视觉文档模型
- [04-layout-and-predicates.md](04-layout-and-predicates.md) 布局与谓词策略矩阵
- [06-render.md](06-render.md) 渲染后端设计
- [09-rendering-ecosystem.md](09-rendering-ecosystem.md) MoonBit 绘制引擎生态调研
