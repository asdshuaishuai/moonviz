---
moonbit:
  backend: native
  import:
    - path: moonviz/decl
      alias: decl
moonviz:
  format: visual-document
  revision: 65
  title: MoonViz 文档
  entry: t_login
  artboards:
    - t_login
    - t_home
    - t_prof
  flows:
    - from: t_login
      to: t_home
      trigger: tap:login_btn
    - from: t_home
      to: t_prof
      trigger: tap:activity_0
---

# MoonViz 文档

这是一份 MoonBit `.mbt.md` 视觉文档。人类画布操作与 Agent 修改都必须回写到本文件；Moonviz 只从本文件重新构建和渲染画布。

## t_login

<!-- moonviz:artboard t_login -->
```mbt
///| @moonviz:visual t_login
fn visual_t_login() -> @decl.Prototype {
  let page = @decl.prototype(name="t_login", width=390, height=844)
  page.add(@decl.generic_node(id="logo",component="badge",kind="rect",width=@decl.fixed(64),height=@decl.fixed(64),x=163,y=120,text="",fill="#4B6BFB",stroke="none",stroke_width=0,radius=999,opacity=1,font_size=14,text_color="#FFFFFF",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="welcome_title",component="heading",kind="text",width=@decl.fixed(200),height=@decl.fixed(36),x=95,y=220,text="欢迎回来",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=24,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="subtitle",component="body_text",kind="text",width=@decl.fixed(200),height=@decl.fixed(18),x=95,y=258,text="登录以继续",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=12,text_color="#9098A1",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="email_input",component="text_input",kind="rect",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=340,text="邮箱地址",fill="#E8EAF6",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="password_input",component="text_input",kind="rect",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=404,text="密码",fill="#E8EAF6",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="forgot_link",component="body_text",kind="text",width=@decl.fixed(140),height=@decl.fixed(18),x=230,y=468,text="忘记密码？",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=12,text_color="#9098A1",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="login_btn",component="button",kind="rect",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=520,text="登 录",fill="#4B6BFB",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#FFFFFF",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="divider1",component="divider",kind="rect",width=@decl.fixed(342),height=@decl.fixed(1),x=24,y=600,text="",fill="#E0E0E0",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="signup_btn",component="button",kind="rect",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=630,text="没有账号？立即注册",fill="#E8EAF6",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page
}
```

```mbt check
test "t_login visual declaration" {
  let page = @decl.prototype(name="t_login", width=390, height=844)
  page.add(@decl.generic_node(id="logo",component="badge",kind="rect",width=@decl.fixed(64),height=@decl.fixed(64),x=163,y=120,text="",fill="#4B6BFB",stroke="none",stroke_width=0,radius=999,opacity=1,font_size=14,text_color="#FFFFFF",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="welcome_title",component="heading",kind="text",width=@decl.fixed(200),height=@decl.fixed(36),x=95,y=220,text="欢迎回来",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=24,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="subtitle",component="body_text",kind="text",width=@decl.fixed(200),height=@decl.fixed(18),x=95,y=258,text="登录以继续",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=12,text_color="#9098A1",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="email_input",component="text_input",kind="rect",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=340,text="邮箱地址",fill="#E8EAF6",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="password_input",component="text_input",kind="rect",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=404,text="密码",fill="#E8EAF6",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="forgot_link",component="body_text",kind="text",width=@decl.fixed(140),height=@decl.fixed(18),x=230,y=468,text="忘记密码？",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=12,text_color="#9098A1",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="login_btn",component="button",kind="rect",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=520,text="登 录",fill="#4B6BFB",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#FFFFFF",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="divider1",component="divider",kind="rect",width=@decl.fixed(342),height=@decl.fixed(1),x=24,y=600,text="",fill="#E0E0E0",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="signup_btn",component="button",kind="rect",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=630,text="没有账号？立即注册",fill="#E8EAF6",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  assert_eq(page.check().length(), 0)
  assert_true(page.render().contains("<svg"))
}
```

## t_home

<!-- moonviz:artboard t_home -->
```mbt
///| @moonviz:visual t_home
fn visual_t_home() -> @decl.Prototype {
  let page = @decl.prototype(name="t_home", width=390, height=844)
  page.add(@decl.generic_node(id="top_bar",component="app_bar",kind="rect",width=@decl.fixed(390),height=@decl.fixed(56),text="登录成功",fill="#4B6BFB",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_0",component="card",kind="frame",width=@decl.fixed(163),height=@decl.fixed(96),x=24,y=80,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="消息: 3 \(未读\)",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_1",component="card",kind="frame",width=@decl.fixed(163),height=@decl.fixed(96),x=203,y=80,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="收藏: 12",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_2",component="card",kind="frame",width=@decl.fixed(163),height=@decl.fixed(96),x=24,y=190,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="订单: 8",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_3",component="card",kind="frame",width=@decl.fixed(163),height=@decl.fixed(96),x=203,y=190,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="积分: 2\,460",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="chart_area",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(200),x=24,y=310,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="本周概览",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_title",component="heading",kind="text",width=@decl.fixed(200),height=@decl.fixed(24),x=24,y=540,text="最近动态",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=16,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_0",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=576,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="个人信息完善度 80%，点击查看",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_1",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=638,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="新粉丝 +128",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_2",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=700,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="作品被收藏 32 次",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_3",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=762,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="收到 5 条新评论",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="bottom_div",component="divider",kind="rect",width=@decl.fixed(390),height=@decl.fixed(1),y=820,text="",fill="#E0E0E0",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page
}
```

```mbt check
test "t_home visual declaration" {
  let page = @decl.prototype(name="t_home", width=390, height=844)
  page.add(@decl.generic_node(id="top_bar",component="app_bar",kind="rect",width=@decl.fixed(390),height=@decl.fixed(56),text="登录成功",fill="#4B6BFB",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_0",component="card",kind="frame",width=@decl.fixed(163),height=@decl.fixed(96),x=24,y=80,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="消息: 3 \(未读\)",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_1",component="card",kind="frame",width=@decl.fixed(163),height=@decl.fixed(96),x=203,y=80,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="收藏: 12",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_2",component="card",kind="frame",width=@decl.fixed(163),height=@decl.fixed(96),x=24,y=190,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="订单: 8",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_3",component="card",kind="frame",width=@decl.fixed(163),height=@decl.fixed(96),x=203,y=190,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="积分: 2\,460",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="chart_area",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(200),x=24,y=310,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="本周概览",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_title",component="heading",kind="text",width=@decl.fixed(200),height=@decl.fixed(24),x=24,y=540,text="最近动态",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=16,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_0",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=576,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="个人信息完善度 80%，点击查看",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_1",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=638,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="新粉丝 +128",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_2",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=700,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="作品被收藏 32 次",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="activity_3",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(52),x=24,y=762,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="收到 5 条新评论",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="bottom_div",component="divider",kind="rect",width=@decl.fixed(390),height=@decl.fixed(1),y=820,text="",fill="#E0E0E0",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  assert_eq(page.check().length(), 0)
  assert_true(page.render().contains("<svg"))
}
```

## t_prof

<!-- moonviz:artboard t_prof -->
```mbt
///| @moonviz:visual t_prof
fn visual_t_prof() -> @decl.Prototype {
  let page = @decl.prototype(name="t_prof", width=390, height=844)
  page.add(@decl.generic_node(id="top_bar",component="app_bar",kind="rect",width=@decl.fixed(390),height=@decl.fixed(56),text="个人信息",fill="#FFFFFF",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="avatar",component="badge",kind="rect",width=@decl.fixed(104),height=@decl.fixed(104),x=143,y=90,text="AB",fill="#4B6BFB",stroke="none",stroke_width=0,radius=999,opacity=1,font_size=14,text_color="#FFFFFF",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="user_name",component="heading",kind="text",width=@decl.fixed(200),height=@decl.fixed(28),x=95,y=214,text="张小明 \(管理员\)",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=20,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="user_bio",component="body_text",kind="text",width=@decl.fixed(200),height=@decl.fixed(18),x=95,y=246,text="前端工程师 · 已登录",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=12,text_color="#9098A1",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_0",component="card",kind="frame",width=@decl.fixed(90),height=@decl.fixed(60),x=44,y=290,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="Posts: 128",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_1",component="card",kind="frame",width=@decl.fixed(90),height=@decl.fixed(60),x=154,y=290,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="Followers: 4.2K",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_2",component="card",kind="frame",width=@decl.fixed(90),height=@decl.fixed(60),x=264,y=290,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="Following: 389",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="follow_btn",component="button",kind="rect",width=@decl.fixed(163),height=@decl.fixed(44),x=24,y=380,text="关注",fill="#4B6BFB",stroke="none",stroke_width=0,radius=10,opacity=1,font_size=14,text_color="#FFFFFF",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="message_btn",component="button",kind="rect",width=@decl.fixed(163),height=@decl.fixed(44),x=203,y=380,text="私信",fill="none",stroke="none",stroke_width=0,radius=10,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="posts_title",component="heading",kind="text",width=@decl.fixed(100),height=@decl.fixed(24),x=24,y=450,text="最近作品",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=16,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="post_0",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(96),x=24,y=486,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="设计系统重构方案",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="post_1",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(96),x=24,y=596,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="移动端组件库 v2",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="post_2",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(96),x=24,y=706,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="品牌视觉升级",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page
}
```

```mbt check
test "t_prof visual declaration" {
  let page = @decl.prototype(name="t_prof", width=390, height=844)
  page.add(@decl.generic_node(id="top_bar",component="app_bar",kind="rect",width=@decl.fixed(390),height=@decl.fixed(56),text="个人信息",fill="#FFFFFF",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="avatar",component="badge",kind="rect",width=@decl.fixed(104),height=@decl.fixed(104),x=143,y=90,text="AB",fill="#4B6BFB",stroke="none",stroke_width=0,radius=999,opacity=1,font_size=14,text_color="#FFFFFF",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="user_name",component="heading",kind="text",width=@decl.fixed(200),height=@decl.fixed(28),x=95,y=214,text="张小明 \(管理员\)",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=20,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="user_bio",component="body_text",kind="text",width=@decl.fixed(200),height=@decl.fixed(18),x=95,y=246,text="前端工程师 · 已登录",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=12,text_color="#9098A1",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_0",component="card",kind="frame",width=@decl.fixed(90),height=@decl.fixed(60),x=44,y=290,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="Posts: 128",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_1",component="card",kind="frame",width=@decl.fixed(90),height=@decl.fixed(60),x=154,y=290,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="Followers: 4.2K",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="stat_2",component="card",kind="frame",width=@decl.fixed(90),height=@decl.fixed(60),x=264,y=290,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="Following: 389",fill="none",stroke="none",stroke_width=0,radius=8,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="follow_btn",component="button",kind="rect",width=@decl.fixed(163),height=@decl.fixed(44),x=24,y=380,text="关注",fill="#4B6BFB",stroke="none",stroke_width=0,radius=10,opacity=1,font_size=14,text_color="#FFFFFF",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="message_btn",component="button",kind="rect",width=@decl.fixed(163),height=@decl.fixed(44),x=203,y=380,text="私信",fill="none",stroke="none",stroke_width=0,radius=10,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="posts_title",component="heading",kind="text",width=@decl.fixed(100),height=@decl.fixed(24),x=24,y=450,text="最近作品",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=16,text_color="#1A1C1E",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="post_0",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(96),x=24,y=486,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="设计系统重构方案",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="post_1",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(96),x=24,y=596,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="移动端组件库 v2",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  page.add(@decl.generic_node(id="post_2",component="card",kind="frame",width=@decl.fixed(342),height=@decl.fixed(96),x=24,y=706,layout=@decl.flex(direction=@decl.vertical, gap=8, padding=16, justify=@decl.justify_start),text="品牌视觉升级",fill="#FFFFFF",stroke="none",stroke_width=0,radius=12,opacity=1,font_size=14,text_color="#111111",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",constraint="lt"))
  assert_eq(page.check().length(), 0)
  assert_true(page.render().contains("<svg"))
}
```

