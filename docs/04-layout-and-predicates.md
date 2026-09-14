# 04 · 布局引擎与"不崩"谓词

## 布局：v1 内置求解器 → chicle / crater-layout

**v1（本仓库，已实现）**：`core/layout.mbt` 两遍法求解器——

1. 自顶向下解尺寸：Fixed 直取；交叉轴 Fill 取内容盒；主轴 Fill 均分
   `内容主轴 − Σ定值 − Σgap`；Hug 按内在尺寸（v1 仅 Text，CJK 全角 1.0×字号、
   其余 0.6×、行高 1.5；M2 由编辑器实测回填）。
2. 自顶向下解位置：栈布局按游标 + 交叉轴对齐规格；绝对定位按相对父矩形。
3. 解不开的约束记入 `SolveFailure`（`NegativeResidual` / `UnsupportedSpec` /
   `MissingNode`），**求解器永远产出有限矩形，失败交给谓词层定级**。

**M1 替换**：声明编译产物转换为 `chicle` 的 JSON 布局文档（或
`moon add mizchi/crater-layout`），映射关系：

| 本仓库语义 | chicle 字段 |
| :--- | :--- |
| `Fixed(v)` / `Fill` / `Hug` | `width/height: 数值` / `grow:1` / `auto` |
| `StackLayout(dir, gap, padding, justify)` | `flow` / `gap` / `padding` / `align` |
| 绝对定位节点 | `absolute` |
| 百分比 / 弹性（预留） | `50%` / `1fr` |

切换时**谓词层不动**——谓词接口（纯函数 `(Document, SolvedLayout) → Violations`）
就是求解器的替换契约。先用简单 Flex 场景对拍两个求解器输出，再整体切换。

## 不崩谓词（core/predicates.mbt，已实现）

对 `(Document, SolvedLayout)` 的纯函数检查，五条：

| # | 谓词 | 定义 | 分级 |
| :--- | :--- | :--- | :--- |
| P0 | `tree_valid` | 单根可达、引用完整、无重复引用/成环、无孤儿 | 结构·双路线硬阻断 |
| P1 | `size_valid` | 所有求解矩形宽高非负、有限 | 结构·双路线硬阻断 |
| P2 | `contained_in_parent` | Frame 的子节点 ⊆ 内容盒（栈与绝对层都查） | 视觉·人软 / Agent 硬 |
| P3 | `no_sibling_overlap` | 同一 Frame 内兄弟节点两两不相交（栈与绝对层都查） | 视觉·人软 / Agent 硬 |
| P4 | `constraint_solvable` | 求解失败 = 约束系统无解 | 视觉·人软 / Agent 硬 |

策略矩阵（core/policy.mbt `decide()`）：

- **HumanGate**：结构谓词阻断（编辑器交互保证极少触发），视觉谓词放行并记为视觉债——
  人类有最终决定权，工具只提醒。
- **AgentGate**：全部阻断，整体拒绝。注意语义：Agent 提交前若文档已有视觉债，
  补丁必须**连同视觉债一起修复**才能通过——不允许把破损状态固化。

每条违规携带 `node_id + detail`，`Violation::to_json()` 输出结构化错误，
Agent 据此定位修复（docs/07）。

## 形式化验证：迁移路径

`moon prove`（`proof_ensure` + Why3/SMT）官方仍标记**实验性**，MVP 不依赖。
谓词刻意写成无副作用的几何性质（`contains_rect` / `intersects` / 非负有限），
与 P0–P3 的数学定义一一对应——待工具链成熟，把运行时断言升级为
`.mbtp` 谓词 + `moon prove` 证明义务，调用方零改动。
