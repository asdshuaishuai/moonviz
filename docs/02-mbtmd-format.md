# 02 · `.mbt.md` 事实源与 Moonviz 视觉扩展

## 基础格式：MoonBit 文学化源码

`.mbt.md` 是 **MoonBit 官方支持的文学化 Markdown 源码文件**，不是 Moonviz 自定义的普通 Markdown，也不是 HTML 原型格式。文件可放在 MoonBit package 内，或作为独立文件传给：

```bash
moon check design.mbt.md
moon test design.mbt.md
```

MoonBit 官方代码块语义如下：

| Fence | MoonBit 工具链行为 | Moonviz 视觉渲染行为 |
| :--- | :--- | :--- |
| ````mbt```` | 编译 MoonBit 源码；不自动创建测试入口 | 仅当它被显式标记为 visual block 时解析为画板 |
| ````mbt check```` | MoonBit 文档测试；`test { ... }` / `async test` 会被检查与执行 | 只做验收，绝不产生第二份画板状态 |
| ````mbt nocheck```` | 展示 MoonBit，不编译、不测试 | 仅展示 |
| ````moonbit```` | 普通文档代码块，不编译、不测试 | 仅展示 |

普通 Markdown 正文也是文档的一部分：它保留产品意图、约束和修改记录，但不被当作 MoonBit 代码或页面 DSL 执行。

## Front matter

一份 Studio 项目对应一份 `.mbt.md` 源文件。front matter 同时保留官方 MoonBit 配置与 Moonviz 自己的命名空间：

```yaml
---
moonbit:
  backend: native
  import:
    - path: moonviz/decl
      alias: decl
moonviz:
  format: visual-document
  revision: 3
  title: 登录流程
  entry: login
  artboards:
    - login
    - dashboard
  flows:
    - from: login
      to: dashboard
      trigger: tap:submit
---
```

- `moonbit:` 是 MoonBit 工具链配置，可声明 `import`、`deps` 和 `backend`。
- `moonviz:` 是 Moonviz 的视觉文档扩展：它声明 revision、入口画板、画板 ID 与跨画板流程。
- Moonviz 不覆盖或重新解释官方 `moonbit:` 字段。

## Moonviz visual block

Moonviz 只渲染显式 visual block，不执行任意 MoonBit 代码来猜测页面。一个画板使用一个紧邻标记的 `mbt` 代码块：

````markdown
## 登录页

这里是人类和 Agent 共读的设计意图。

<!-- moonviz:artboard login -->
```mbt
///| @moonviz:visual login
fn visual_login() -> @decl.Prototype {
  let page = @decl.prototype(name="login", width=390.0, height=844.0)
  page.set_layout(@decl.flex(direction=@decl.vertical, gap=16.0, padding=24.0))
  page.add(@decl.text(id="title", content="欢迎回来", size=28.0, weight="bold"))
  page.add(@decl.button(id="submit", width=@decl.fill, height=@decl.fixed(48.0), label="登录"))
  page
}
```

```mbt check
test "login visual declaration" {
  let page = visual_login()
  assert_eq(page.check().length(), 0)
  assert_true(page.render().contains("登录"))
}
```
````

约束：

1. `<!-- moonviz:artboard <id> -->` 必须紧邻其后的 ````mbt```` visual block。
2. 一个 visual block 只能构造一个 `@decl.prototype` 入口。
3. 同一份 MBT 文件可含多个 visual block，对应多个画板。
4. visual block 只能使用 Moonviz 支持的公开 `@decl` DSL。包含不可识别、动态或任意 MoonBit 逻辑时，引擎返回带源文件行号的 `not_renderable` 错误。
5. `mbt check` 可重新构造 visual function 做验收，但不会成为另一份持久化页面。
6. 节点 `id` 是人类与 Agent 的共同引用语言，不得无故改名。

## 视觉渲染链路

MoonBit 编译器负责源码、类型与文档测试；它不负责生成视觉画布。Moonviz 的渲染链路固定为：

```text
DDP 密文
  → Moonviz DDP codec 解密/解压
  → 完整 UTF-8 `.mbt.md`
  → MBT scanner（front matter + fence + visual block）
  → `@decl` declaration parser
  → Prototype / Document / Scene Graph
  → `solve()`
  → `validate()`
  → `render_svg()` / `MoonVizRT::render_plan()`
  → Studio 画布
```

SVG 和 RenderPlan 是 `.mbt.md` 的派生结果，仅供当前 Studio 显示；它们不是源文件、不会写入 DDP，也不能被用来反向恢复项目真相。

## 人类与 Agent 的同一提交边界

`.mbt.md` 是唯一事实源：

- **人类路径**：画布拖拽、属性调整或组件操作先在临时 Document 上执行 `HumanGate`。结构违规拒绝；视觉违规作为 debt 允许。成功后操作被规范化写回 MBT，再从写回后的 MBT 全量重载并渲染。
- **Agent 路径**：Agent 读取并修改完整 MBT。引擎在 `AgentGate` 下重新解析和校验；任一结构或视觉违规都会整体拒绝。成功后才写回 canonical MBT，再重新渲染。

内存 Project、命令日志、SVG、RenderPlan 和前端状态都只能作为派生缓存。任何写回失败都不能使内存状态成为事实源。

## DDP

`.ddp` 是**一个完整 `.mbt.md` 的认证加密表示**：

```text
DDP bytes
├── `DDP1` 魔数与 codec 版本
├── Argon2id salt
├── XChaCha20-Poly1305 nonce
└── 认证密文（压缩后的完整 UTF-8 `.mbt.md`）
```

DDP 不是 ZIP，不含 manifest、文件清单、HTML、OpenUI、`pm-design.md` 或 `.mvz.json`。解密成功只是读取 MBT 的第一步；Moonviz 仍必须扫描、解析、校验所有 visual block 与 flow，成功后才替换当前 Studio 项目。

错误密码、认证失败、损坏容器、非法 UTF-8、非法 MBT fence、重复画板、无效 flow 引用或 Gate 阻断都必须原子拒绝，当前项目保持不变。

## 规范化规则

1. 人类或 Agent 修改后，输出必须是一份完整、合法的 `.mbt.md`。
2. `moonviz.revision` 单调递增，表示提交后的文档版本。
3. 引擎只规范化受影响的 visual 声明；普通 Markdown、`mbt nocheck` 和 `moonbit` 文档块不能被误删或误执行。
4. 每次提交后，都以规范化 MBT 为输入重新构建画布；不得从旧 SVG 或命令日志刷新。
