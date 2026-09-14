# 03 · 视觉文档模型（core/）

内存中的 Scene Graph 是布局、谓词、渲染的计算结构；`.mbt.md` 是它的持久化
事实源。二者通过 docs/05 的同步管道对齐。

## 节点

```moonbit
pub(all) struct Node {
  id : String            // 全文档唯一，人类与 Agent 共同的引用语言
  kind : NodeKind        // Frame / Group / Rect / Text / Image
  name : String
  width : SizeSpec       // Fixed(v) / Fill / Hug
  height : SizeSpec
  x : PosSpec            // Fixed / AlignStart / AlignEnd / CenterInParent
  y : PosSpec
  layout : StackLayout?  // 仅 Frame；None = 绝对定位容器
  style : NodeStyle
  text : String          // Text 的内容；Rect 上非空即为居中标签（按钮/输入框）
  children : Array[String]
}
```

节点树**平铺存储**在 `Document.nodes : Map[String, Node]`，`children` 只存 id。
这是有意的：补丁、日志、JSON 导出、增量同步都以 id 为键，Agent 读到的
JSON 与内存结构一一对应。

## 尺寸与位置语义

| 规格 | 栈布局交叉轴 | 栈布局主轴 | 绝对定位 |
| :--- | :--- | :--- | :--- |
| `Fixed(v)` | 定值 | 定值 | 定值（相对父矩形） |
| `Fill` | 占满内容盒 | 均分剩余空间（分不到 → 无解，见 docs/04） | 从自身偏移填满父矩形剩余空间 |
| `Hug` | 包裹内容 | 包裹内容 | 包裹内容（v1 仅 Text） |

位置规格相对**父容器内容盒**；栈布局中主轴分量被忽略（由布局游标决定）。

## 文档与版本

```moonbit
pub(all) struct Document {
  mut root_id : String
  mut nodes : Map[String, Node]
  mut revision : Int                  // 单调递增，乐观锁基准
  mut journal : Array[JournalEntry]   // 每次合并一条
}
```

`JournalEntry { revision, source: human|agent, message, violation_count }`。
**人类操作也被规范化记录**——journal 里的每次合并都携带触发它的完整变更，
Agent 读取 `.mbt.md` 时看到的就是这些操作的最终结果，而非事件流。

## 人类路线的事务入口

`apply_human_op(doc, patch)`（core/patch.mbt）：

1. `base_revision` 校验（乐观锁）；
2. 在候选副本上应用全部操作（Insert/Update/Move/Delete）；
3. 全量校验：结构违规 → `StructuralBlock`（拒绝）；视觉违规 → 作为
   **视觉债**放行，随 journal 记录 `violation_count`；
4. 通过才整体合并、revision +1。

Agent 不走 JSON 补丁（v1）：Agent 的提交物是 `.mbt.md` 声明，编译产物经
`Prototype.check()` 走同一套谓词。patch 机制保留给人类编辑器与未来的
细粒度 Agent 工具调用。

## JSON 视图

`Document::to_json()` 输出嵌套 children 的规范 JSON；`Violation::to_json()`、
`PatchError::to_json()` 输出结构化错误。这是同步管道（docs/05）与 Agent
错误反馈（docs/07）的数据格式。
