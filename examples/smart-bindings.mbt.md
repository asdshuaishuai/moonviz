---
moonbit:
  backend: native
  import:
    - path: moonviz/decl
      alias: decl
moonviz:
  format: visual-document
  revision: 6
  theme: light
  title: MoonViz 文档
  entry: home
  artboards:
    - home
---

# MoonViz 文档

这是一份 MoonBit `.mbt.md` 视觉文档。人类画布操作与 Agent 修改都必须回写到本文件；Moonviz 只从本文件重新构建和渲染画布。

## home

<!-- moonviz:artboard home -->
```mbt
///| @moonviz:visual home
fn visual_home() -> @decl.Prototype {
  let page = @decl.prototype(name="home", width=400, height=240)
  page.add(@decl.generic_node(id="title",component="body_text",kind="text",width=@decl.fixed(360),height=@decl.fixed(40),x=20,y=20,text="{{user.name}}",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#42474F",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",text_align="left",font_style="normal",stroke_dash="solid",visible=true,constraint="lt"))
  page.add(@decl.generic_node(id="score",component="body_text",kind="text",width=@decl.fixed(360),height=@decl.fixed(30),x=20,y=80,text="得分：{{report.score}}（{{report.grade}}）",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#42474F",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",text_align="left",font_style="normal",stroke_dash="solid",visible=true,constraint="lt"))
  page
}
```

```mbt check
test "home visual declaration" {
  let page = @decl.prototype(name="home", width=400, height=240)
  page.add(@decl.generic_node(id="title",component="body_text",kind="text",width=@decl.fixed(360),height=@decl.fixed(40),x=20,y=20,text="{{user.name}}",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#42474F",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",text_align="left",font_style="normal",stroke_dash="solid",visible=true,constraint="lt"))
  page.add(@decl.generic_node(id="score",component="body_text",kind="text",width=@decl.fixed(360),height=@decl.fixed(30),x=20,y=80,text="得分：{{report.score}}（{{report.grade}}）",fill="none",stroke="none",stroke_width=0,radius=0,opacity=1,font_size=14,text_color="#42474F",font_weight="normal",shadow="none",rotate=0,blur=0,blend="normal",line_height=1.5,tracking=0,flip="none",text_align="left",font_style="normal",stroke_dash="solid",visible=true,constraint="lt"))
  assert_eq(page.check().length(), 0)
  assert_true(page.render().contains("<svg"))
}
```

