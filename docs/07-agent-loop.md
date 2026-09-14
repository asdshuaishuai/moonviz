# 07 · Agent 工作流

## 标准循环

```
读 .mbt.md（正文意图 + 声明 + front matter version）
  → 生成/修改声明（编辑对应 mbt check 块）
  → moon check          # 类型与语法，秒级
  → moon test           # 声明块的谓词断言，原型即测试
  → 通过：写回 .mbt.md，version+1，画布自动更新
  → 失败：读编译错误 / 违规 JSON → 修复 → 重试
```

Agent 的两种失败与两种反馈：

1. **编译失败**：moonc 的类型错误（含位置）。声明 DSL 把 core 类型封装后，
   错误面收敛在 decl API 的参数上，修复成本低。
2. **谓词失败**：`Violation::to_json()` 输出
   `{"predicate":"contained_in_parent","node_id":"login","detail":"子节点超出父容器 root 的内容盒"}`
   —— 节点 id + 谓词 + 详情，Agent 据此改声明（如 `width: fixed(400)` → `fill`）。

## 典型演化示例（与 decl/login.mbt.md 的修改记录对应）

> 指令："把登录按钮宽度改成和输入框一样"

1. 读文档：按钮声明 `@decl.button(id="login", width=@decl.fixed(200.0), …)`，
   输入框是 `width=@decl.fill`；正文意图"按钮与输入框等宽"。
2. 改一行：`fixed(200.0)` → `fill`。
3. `moon test`：布局重解，按钮与输入框同为内容盒宽，无溢出无重叠，断言通过。
4. 写回，version 3，修改记录追加一行。

对比 JSON 补丁协议：声明即代码让"改宽度"就是改一个参数，
类型系统替 Agent 挡住所有非法表达；结构化错误只在语义层（谓词）出现。

## 语义约束（Agent 必须知道）

- **乐观锁**：front matter `version` 不匹配 → 重新读取后再改。
- **视觉债**：文档已有软违规（人类拖出来的重叠）时，Agent 的提交必须连同
  债务一起修复；把破损状态固化的提交会被整体拒绝。
- **id 稳定**：节点 id 是人类与 Agent 的共享引用，不得无故重命名；
  重命名 = 破坏画布上的选区、日志与同步索引。
- **正文与声明一致**：正文写的意图（"等宽"）必须在声明里成立（`fill`），
  二者矛盾以声明为准并回写正文。

## 工具链集成（M2+）

- **pi-moonbit**：把上述循环托管为 agent loop——读文档、编辑块、
  `moon check`/`moon test` 作为工具调用，结构化违规作为工具结果回灌。
- **moonclaw**：文件级编辑与执行沙箱。
- 提示词要点已在本文件：错误反馈格式、语义约束、DSL API 表（docs/02）。
