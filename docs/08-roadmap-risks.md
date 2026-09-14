# 08 · 实现路径与风险

## 当前状态（M0，本仓库）

已落地并经 `moon test` 验证（14/14 绿）：

- 视觉文档模型：节点树、尺寸/位置语义、revision + journal（core/）。
- v1 布局求解器：Fixed/Fill/Hug/栈布局/绝对定位，失败显式建模（core/layout.mbt）。
- 不崩谓词 P0–P4 + 双路线策略矩阵（core/predicates.mbt, policy.mbt）。
- 人类路线事务：结构硬、视觉软、视觉债记录（core/patch.mbt）。
- SVG 管线 + 结构化错误 JSON（core/svg.mbt, json.mbt）。
- **`.mbt.md` 事实源端到端**：decl 声明 DSL + login.mbt.md 随 moon 工具链编译执行。
- 人类画布演示（editor/index.html）：拖拽软反馈 + `.mbt.md` 同步视图。

## 阶段

| 阶段 | 目标 | 核心工作 | 验收 |
| :--- | :--- | :--- | :--- |
| MVP（本仓库） | `.mbt.md` → 布局 → SVG 端到端 | 见上 | `moon test` 全绿 |
| M1 | 布局与同步换正式件 | chicle/crater-layout 适配对拍；`@mizchi/markdown` 增量同步；`mizchi/svg` 场景图 | 拖拽全程 <16ms/帧；两求解器输出一致 |
| M2 | 编辑器 MVP | 属性面板/组件库/吸附；文本实测回填；Canvas 交互层 | 墨刀级基础体验 |
| M3 | Agent 闭环 | pi-moonbit 托管循环；失败自修复；多原型工程化 | 自然语言 → 谓词全过 → 画布可见，无人工干预 |
| M4 | 高保真与协作 | `vg` 导出、C-FFI Skia/Qt6；lomo CRDT | 渐变/阴影/导出；双人并发不丢单 |

## 风险与缓解

| 风险 | 影响 | 缓解 |
| :--- | :--- | :--- |
| `moon prove` 实验性 | 验证层不稳定 | MVP 用运行时断言；谓词保持纯函数形态可平移 |
| chicle/crater 成熟度 | 布局引擎 bug | v1 内置求解器兜底；对拍通过再切换；谓词接口即替换契约 |
| 视觉文档模型自研量 | 最大工作量 | 已完成 M0 核心；kwiver 架构参照 |
| 双向同步一致性 | 冲突/丢单 | 串行 + version 乐观锁（MVP）；lomo CRDT（后续） |
| `.mbt.md` 黑盒测试限制 | 私有定义不可用 | 声明走 decl 公开 API；白盒逻辑放 core 内部测试 |
| 前端画布性能 | 大文档卡顿 | 增量解析 + 布局脏区传播 + 渲染 diff |
| LLM 输出不稳定 | 声明写错 | 声明 DSL 面小 + moon check 秒级反馈 + 结构化违规回灌 |
