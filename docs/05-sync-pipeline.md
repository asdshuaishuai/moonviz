# 05 · 双向增量同步管道

## 目标

人类拖拽（每帧）与 Agent 编辑（每次提交）都作用在 `.mbt.md` 上，
同步延迟必须低于人的感知阈值。`@mizchi/markdown`（纯 MoonBit、CST 基、
增量解析约 10μs 且与文档大小无关）是这条管道的解析底座。

## 两个方向

**人类 → `.mbt.md`**：

```
拖拽帧 → 内存文档预览（求解+谓词，仅供软反馈）
松手   → apply_human_op 合并（事务）
       → 变更节点 → 定位 .mbt.md 中对应声明行（CST 节点 id 索引）
       → insertEdit 生成声明块的增量编辑（其余文档字节不变）
```

**`.mbt.md` → 人类**：

```
Agent 写回声明 → 增量解析，取变更的 CST 子树
  → 仅重编译变更块 → 新 Prototype → build() → 新 Document
  → 与内存文档 diff（按节点 id）→ 布局 → 渲染 diff 区域
```

## CST 索引：声明 ↔ 节点的映射

每个 `mbt check` 块内的声明按**节点 id** 组织（`text_input(id="username", …)`）。
同步管道维护 `id → CST 节点区间` 索引：

- 人类改了 `username` 的 x → 精确替换该调用的对应参数片段；
- Agent 改了 `username` 的宽度 → 只重解析该块，diff 出受影响节点。

这要求声明代码保持**规整形态**（每组件一个调用、每参数一行）——
由 `moon fmt` 保证。声明块是机器可写的规整代码，不是自由散文；
自由表达放在 Markdown 正文里。

## 一致性策略（MVP）

- **串行修改**：人类提交与 Agent 提交排队执行，同一时刻只有一个写者。
- **revision 乐观锁**：`.mbt.md` front matter `version` 与内存 `revision` 对齐；
  Agent 基于 v3 生成的修改，落盘时发现已是 v4 → 重新读取后再改。
- **提交边界对齐**：内存合并成功才写 `.mbt.md`；写失败则回滚内存
  （`.mbt.md` 永远是事实源，内存只是缓存视图）。

## CRDT（后续增强）

多人 / 多 Agent 并发时引入 `lomo`（MoonBit 移植的 Loro CRDT，容器语义与
确定性合并保留）：`.mbt.md` 的声明块映射为 Loro Map/List 容器，冲突合并
交给 CRDT，工具链验证仍在提交后进行。MVP 不引入。
