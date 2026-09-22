# MoonViz 发展路线图

> 当前基线：**v0.1.1-session**（`engine-v0.1.1-fix` 起）· `moon test` 190/190 · 仓库 90+ commits

## 当前基线盘点

| 维度 | 现状 |
|---|---|
| 引擎内核 | 100% MoonBit，48 个核心模块、275+ 公开函数；不崩谓词 5 项 + 双门禁 |
| 工具面 | CLI 65 命令 · MCP 52 工具（含 inputSchema 字典）· WASM 双产物 70/51 导出（session 26）· Node SDK |
| 组件与模板 | 52 组件 × 93 变体 · 14 个整页模板（移动 + Web/桌面） |
| 分发 | npm 7 包 + GitHub Releases 全产物 10 项（4 平台 tarball + 双 wasm + npm 全家族） |
| 人类体验 | Playground 设计工作台（设计/预览双模式）+ deepDesign Studio 画布 |
| 质量治理 | 5 个下游 issue 全闭环；契约测试（wasm/contract_test.mbt）锁定回归 |

## 路线图

按 **能力平权 → 体验深化 → 生态扩展** 三层推进。优先级依据真实缺口测量，不预设时间表。

### P0 · 能力平权（核心模块 → 边界全通）

**1. 搁浅模块出井。** 以下模块已在 core 实现并经测试，但尚未到达任何调用边界（CLI/MCP/WASM/SDK 均不可达）：

| 模块 | 能力 | 缺口 |
|---|---|---|
| `core/collab.mbt` | 多 Agent 操作变换（OT）、冲突检测、三方合并 | 零暴露 |
| `core/history.mbt` | 设计版本控制：时间旅行、分支、变更回放、undo/redo | 零暴露 |
| `core/animation.mbt` | 属性动画：关键帧、缓动函数、时间线编排、CSS 导出 | 零暴露 |
| `core/prototest.mbt` | 原型测试：断言式验证导航/输入/渲染/违规 | 零暴露 |

交付：每个模块按既有模式补齐边界（CLI 命令 + MCP 工具 + 按需 session API），文档同步，测试锚定。

**2. classic wasm 写路径。** Rust/wasmtime 宿主目前只能读（无参调用）。补齐 `session_*` 入参方向：在 wasm 边界导出字符串分配辅助（宿主写入线性内存 → 引擎构造 MoonBit String），打通 `render_mbt` / `apply_*_op` / `session_apply_*` 的双向调用。

**3. Node SDK 会话封装。** `moonviz-engine-sdk` 的 `MoonViz` 类目前走 CLI 通道；对齐 wasm SDK 的 session API 形态（open/apply/lint/…/count），让 Node 宿主与 WASM 宿主共享同一套调用心智。

### P1 · 体验深化

**4. deepDesign Studio 全面接入新引擎。** 引擎能力面（52 工具/25 op/组件库/交互面板/主题令牌）与 Studio 画布对齐：画布撤销/重做（引擎 revision + journal 已就绪）、组件库拖放、交互面板、源码视图直读 `.mbt.md`。

**5. Playground 能力补全。** 动画系统接入（`animation.mbt` → 预览模式实时动效）；用户组件编译入口（MCP `component_compile` 已有，Playground 缺 UI）；原型测试面板（`protest.mbt` 断言可视化运行）。

**6. ddpView 只读查看器。** macOS 原生查看加密 DDP 文档并渲染交互原型（DDP1 加密 / DDP2 免密容器）。

### P2 · 生态扩展

**7. npm 0.2.0 发版。** 纳入 session API 全量 + issues #1–#5 修复 + 双语 README；win32-x64 包待 npm 风控解除后补发（GitHub Releases 渠道已可用，Windows 用户不受阻）。

**8. 在线 API 参考。** 官网已有工具字典（tools.json）与 op 字典（ops.json）；补参数级 API 参考与示例库（每个工具一个最小可运行用例）。

**9. 多 Agent 协作场景落地。** `collab.mbt` 的 OT/冲突解决接进 Studio：两个 Agent 会话同改一份 `.mbt.md`，冲突显式呈现而非静默覆盖。

**10. 性能基线进 CI。** `benchmark.mbt` 的输出（节点数/深度/Fill 密度/评分）纳入构建流水线，布局复杂度回归自动告警。

## 治理原则

- **每条路线以“数据模型已支持但边界不可达/体验未落地”为线索**——core 是资产，边界和体验是债务；
- **能力过界必须同源**：新能力一律从 core 单一事实源派生到各端，字典/测试/文档同步锚定；
- **不破坏既有契约**：`.mbt.md` 格式、双门禁语义、JSON 信封向前兼容，破坏性变更走显式 PR + 契约测试红绿评审。

---

## 附：当前搁浅模块清点（测量于 v0.1.1）

```
模块                公开函数    CLI            MCP                    WASM
core/collab.mbt     OT/冲突/合并  ✓(collab-merge) ✓(collab_merge)      ✗
core/history.mbt    版本控制       ✓(history×7)    ✓(history)           ✗
core/animation.mbt  动画/CSS导出   ✓(anim-css)     ✓(animation_css)     ✗
core/prototest.mbt  原型测试断言   ✓(protest)      ✓(protest)           ✗
core/runtime.mbt    交互运行时     ✓(tap)          ✗                    ✓(session_tap)
core/reasoning.mbt  自然语言约束   ✓(constrain)    ✗                    ✗
core/variants.mbt   变体探索       ✗               △(部分)              ✗
```

> 测量方法：`grep -c "<module>" {cli,mcp,wasm}/main.mbt`。P0-1 已消灭四个 ✗ 行；
> `core/variants.mbt`（fork/score/merge 变体探索）是剩余最后一个搁浅模块，列入下一轮。
