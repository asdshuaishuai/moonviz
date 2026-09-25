# MoonViz 1.0 发展规划

> 分支：`release/1.0`（自主线 f109d15 拉出）· 基线：v0.1.6-fix · `moon test` 209/209
> 本文档是 1.0 的唯一规划事实源；执行中变更直接改这里并走提交评审。

---

## 一、1.0 的定义：首个 API 稳定版

1.0 不是功能清单的终点，而是一条**稳定版承诺**：

- `.mbt.md` 文档格式、26 条 mutating op、`session_*` 会话面、MCP 53 工具（含 inputSchema）、
  classic wasm ABI（72 导出/0 imports）、JSON 信封形态——**全部冻结**；
- 冻结后只增不破：新增能力走新增 op/工具/导出，已有签名与信封字段向前兼容；
- 下游（deepDesign Studio、第三方 wasmtime/Node 宿主）可以按 1.0 锚定构建产品，
  sha512 固定产物升级只遇到新增，不遇到破坏。

**达成即发布 1.0 GA**；在此之前所有版本为 0.x 预发布序列（0.2、0.3…），允许按 #7/#18
先例做破坏性修正（但每次破坏必须走契约测试红绿评审）。

> **发布策略**：1.0 处于正式开发阶段、**不发布**——`release/1.0` 是开发分支，面向用户
> 的发布线仍在 main（0.1.x → 0.2.x 序列）。1.0 tag/GA 只在 M1–M3 全部达成且 GA 门禁
> 走完后出现。

---

## 二、现状基线（规划起点，测量于 v0.1.6-fix）

| 维度 | 现状 | 1.0 缺口 |
|---|---|---|
| 引擎内核 | 100% MoonBit，不崩谓词 5 项 + 双门禁，207→209 测试 | 门语义最后一项缺口：显式层叠（部分相交合法层叠） |
| 工具面 | CLI 65 命令 · MCP 53 工具（inputSchema）· WASM 双产物 72/53 导出 · Node SDK | variants.mbt（变体探索）是最后一个零边界模块 |
| 组件与模板 | 65 组件 × 115 变体 · 14 整页模板（移动 + Web/桌面） | 模板/组件与 AgentGate 全绿已有契约锚 |
| 会话面 | session 28 导出（含 history 撤销/时间旅行、constrain 意图、canonical mbt 回传） | constrain 只覆盖布局意图；层级诉求部分由 #15 豁免承接 |
| 分发 | GitHub Releases 全产物 10 项 · npm 7 包托管于 GitHub（不入 npm 仓库） | 无 |
| 下游 | deepDesign Studio（wasmtime + WebView 双宿主）已接 0.1.6-fix | 消费侧升级节奏与真实 LLM run 指标回收 |
| 质量 | 契约测试锁定双门/信封/句柄/回灌；209/209 | 参数级契约覆盖不全；性能基线未进 CI |

---

## 三、里程碑

### M1 · 语义补全（能力面封顶）——✅ 已完成

1.0 收口前把「半成品语义」补齐，避免冻结后带憾：

- **显式层叠语义 ✅**：`NodeStyle.overlay` 声明（`update <ab> <node> overlay=true`，双门可达）——声明节点与兄弟的重叠为有意层叠，不再记 no_sibling_overlap；decl 往返保持（canonical 条件写出 `overlay=true`，apply_decl_style 解析）；autofix 修复层同步豁免；非 overlay 对照债不被遮蔽。契约测试：压叠移动「未声明拒 → 声明后过」+ canonical 携带声明。
- **variants.mbt 出井 ✅**：CLI 三命令（variants-fork/score/merge）+ MCP `variants` 工具（action 分发，inputSchema 见 tools/list）+ merge 信封裸箭头修为合法 JSON（#10 同类）+ 回归测试（fork 复制/评分覆盖/merge 信封/未知画板）。
- **智能面会话导出复核 ✅**：复核结论——仅 `generate_responsive` 变更文档（新建画板），其已走 `sess_mut_json` 回传 canonical mbt（#19 修复面）；`infer_*`/`extract_design_system`/`benchmark` 为纯只读分析，无 canonical 义务。无需改码。

### M2 · 稳定化（冻结审计）

- **三张冻结表**：op 表（26 条 usage/gates）、session 表（28 导出签名与信封）、
  MCP 表（53 工具 inputSchema）——逐条评审定稿，作为 1.0 契约附件随仓库发布；
- **契约测试全覆盖**：每个 wasm 导出 ×（合法输入 / 非法输入 / 已关句柄 / 空集合）
  四象限断言，消灭 `contains` 式弱断言（一律 JSON.parse 级校验）；
- **性能基线进 CI**：`benchmark.mbt` 输出（节点数/深度/Fill 密度/评分）入构建流水线，
  布局复杂度回归自动告警；
- **安全复核**：DDP 加解密路径、信封转义全量排查（#3/#10 手写信封类清零复核）、
  classic ABI 边界的内存辅助函数。

### M3 · RC → GA

- **文档完备**：官网参数级 API 参考 + 每工具最小可运行示例库（P2-8 提前并入）；
  SKILL.md 与 tools/ops 字典零漂移（脚本校验）；
- **下游验证**：deepDesign 以 1.0 RC 构建真实 LLM run（≥3 轮 × 5 页应用），
  gate 拒绝率、op 往返数、崩溃数指标回收并达标；
- **GA 发布**：tag `engine-v1.0.0`，Release 附稳定版承诺声明与三张冻结表，
  后续 1.0.x 只做修复。

---

## 四、1.0 GA 门禁（验收清单）

- [ ] M1 三项语义全部落地且契约测试锚定
- [ ] 三张冻结表评审定稿并随仓库发布
- [ ] wasm 导出四象限契约覆盖率 100%（72/72）
- [ ] 性能基线进 CI 且无未处置告警
- [ ] 安全复核清单走完（DDP / 信封转义 / ABI 边界）
- [ ] 官网参数级 API 参考 + 示例库上线
- [ ] deepDesign 真实 LLM run 指标达标并出具消费侧验收
- [ ] `moon test` 全量绿、双 wasm 构建 + ABI 断言绿、GitHub Release 10 资产齐全

---

## 五、明确不做（1.0 非目标）

- 多 Agent 实时协作编辑（collab 的 OT 面保留为工具，编辑态协作不在 1.0）；
- 云服务 / 账户体系 / 在线托管（保持纯本地 + 文件分发）；
- npm 仓库重入（维持 GitHub Releases 单一分发渠道，决策复核不早于 1.0 GA）；
- 新增 UI 组件大类（65×115 冻结，扩展走用户组件机制）。

范围控制原则：1.0 的叙事是「**同能力，可承诺**」——冻结已知的好，而不是塞进新的多。

---

## 六、风险与依赖

| 风险 | 应对 |
|---|---|
| MoonBit 工具链 latest 策略引入行为漂移 | CI 双 wasm 构建冒烟 + 契约测试兜底（现状已覆盖） |
| deepDesign 消费侧节奏不同步 | M3 下游验证以其升级 1.0 RC 为准；引擎侧每版保持 sha512 可锚定 |
| 显式层叠语义设计分歧 | M1 内先出设计稿（声明语法/门语义/序列化三节）评审，再实现 |
| 单维护者带宽 | 里程碑按序串行，每个 M 有独立可交付出口；GA 门禁缺一即延后 |
