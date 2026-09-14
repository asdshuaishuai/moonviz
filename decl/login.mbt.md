---
title: 登录页原型
source: agent
version: 3
---

# 登录页原型

页面 390×844，纵向栈布局：标题、用户名输入框、密码输入框、登录按钮。

本文档是**唯一事实源**：人类画布与 Agent 读写的是下面这段声明。
`mbt check` 代码块会随 `moon check` / `moon test` 真实编译——声明即代码，
布局可解、“不崩”谓词全过，这份原型就是可交付的。

```mbt check
///|
test "登录页原型：声明 → 文档 → 布局 → 谓词 → 渲染" {
  let page = @decl.prototype(name="login-page", width=390.0, height=844.0)
  page.set_layout(@decl.flex(direction=@decl.vertical, gap=16.0, padding=24.0))
  page.add(
    @decl.text(id="title", content="欢迎回来", size=28.0, weight="bold"),
  )
  page.add(
    @decl.text_input(
      id="username",
      width=@decl.fill,
      height=@decl.fixed(44.0),
      placeholder="用户名 / 邮箱",
    ),
  )
  page.add(
    @decl.text_input(
      id="password",
      width=@decl.fill,
      height=@decl.fixed(44.0),
      placeholder="密码",
    ),
  )
  page.add(
    @decl.button(
      id="login",
      width=@decl.fill,
      height=@decl.fixed(48.0),
      label="登录",
    ),
  )
  // “不崩”谓词：结构 + 尺寸 + 无溢出 + 无重叠 + 约束可解
  assert_eq(page.check().length(), 0)
  // 渲染管道：SVG 可产出且包含关键内容
  let svg = page.render()
  assert_true(svg.contains("欢迎回来"))
  assert_true(svg.contains("登录"))
}
```

## 修改记录

- v3（agent）：按钮宽度与输入框对齐（`width=@decl.fill`），替换原 `fixed(200.0)`。
- v2（human）：画布微调标题字号 24 → 28。
- v1（agent）：初始化登录页声明。
