# 01 · 架构总览

## 定位

Agent-Native 原型绘制引擎：产品经理/设计师用 Figma 式画布画原型，Agent 用
MoonBit 代码演化原型，**两者作用于同一个 `.mbt.md` 事实源**。

架构边界遵循 kwiver 的已验证模式：**已提交的原型语义属于 MoonBit 内核，
浏览器端只保留渲染和瞬态交互状态。**

## 分层

```
人类画布（editor/）              Agent（任意 LLM 客户端）
     │ 视觉操作事件                    │ 读写声明
     ▼                                ▼
┌─────────────────────────────────────────────┐
│ 视觉文档模型 core/（内存 Scene Graph）        │
│  Document / Node / 布局求解 / 不崩谓词 / 日志 │
└───────────────┬─────────────────────────────┘
                │ 双向增量同步（docs/05）
┌───────────────▼─────────────────────────────┐
│ .mbt.md 事实源（decl/ 内编译）                │
│  Markdown 正文 = 设计意图与约束说明            │
│  ```mbt check``` 代码块 = 可编译的声明         │
└─────────────────────────────────────────────┘
```

core/ 与 decl/ 的分工：

- **core/**：不依赖任何第三方包。文档模型、v1 布局求解器、不崩谓词、
  人类路线的事务与日志（`apply_human_op` + journal）、SVG 输出。
  这是自研工作量最大、也最需要稳定性的部分。
- **decl/**：`.mbt.md` 代码块的**公开 API 面**。组件工厂（`text_input`、`button`、
  `flex`…）把 core 的类型细节封装掉，让声明代码接近设计语言。

## 两条路线的读写路径

**人类 → 文档**：画布拖拽 → 编辑器在内存文档上做预览（每帧求解 + 谓词，
结果只用于软反馈）→ 松手提交 `apply_human_op`（事务：结构违规拒绝，视觉违规
作为"视觉债"放行并记入 journal）→ 提交边界上把变更序列化回 `.mbt.md` 对应声明。

**Agent → 文档**：读取 `.mbt.md` → 生成/修改 `mbt check` 块中的声明 →
`moon check` 编译验证 → 构造 `Prototype` → `check()` 跑不崩谓词 →
通过则写回 `.mbt.md`，画布重新渲染；失败则拿到结构化违规，修复后重试。

## 关键决策记录

| 决策 | 理由 |
| :--- | :--- |
| `.mbt.md` 是事实源，不是内存模型 | LLM 对 Markdown 天然友好；声明随 moon 工具链获得编译级保障；diff/review/版本管理全部复用现有生态 |
| 内存 Scene Graph 仍然自研 | 布局求解、谓词检查、渲染都需要 O(1) 的平铺节点表；`.mbt.md` 是持久层，不是计算结构 |
| 谓词用运行时断言，不用 `moon prove` | `moon prove` 官方标记实验性（docs/04）；谓词 API 保持纯函数形态，验证工具链成熟后可平移 |
| 人类/Agent 共用同一套 Op 与 journal | Agent 读到的永远是规范化的文档表示，而不是人类操作的事件流 |
| 串行修改 + revision 乐观锁（MVP） | 单人 + 单 Agent 场景足够；CRDT（lomo）留作多人协作增强 |
| 布局 v1 用内置两遍法求解器 | 覆盖 Fixed/Fill/Hug/栈布局，语义完全可控；chicle/crater-layout 适配层作为 M1 替换（docs/04） |

## 技术栈映射

| 层 | 现状（本仓库） | 目标（M1+） |
| :--- | :--- | :--- |
| 事实源 | `decl/login.mbt.md` + moon 黑盒测试 | 全量原型文档 + front matter 规范 |
| 文档模型 | `core/`（已实现，14 测试全绿） | 不变，增量演进 |
| 布局 | `core/layout.mbt` 两遍法求解器 | `chicle` / `mizchi/crater-layout` 适配 |
| 同步 | 提交边界全量序列化 | `@mizchi/markdown` 10μs 增量解析 |
| 渲染 | `core/svg.mbt`（SVG 字符串） | `mizchi/svg` 场景图 + `vg` 高保真路径 |
| Agent 集成 | 手工循环（docs/07） | `pi-moonbit` / moonclaw 托管循环 |
