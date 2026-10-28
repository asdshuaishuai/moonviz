// 声明文本往返测试：序列化 → 解析 → 语义等价（白盒，同包直呼 API）
// 运行：moon test

///|
fn expect_rect(
  doc : @core.Document,
  id : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let layout = @core.solve(doc)
  match layout.rect_of(id) {
    Some(r) =>
      if !(r.x == x && r.y == y && r.width == w && r.height == h) {
        abort(
          "节点 \{id} 期望 (\{x}, \{y}, \{w}, \{h})，实际 (\{r.x}, \{r.y}, \{r.width}, \{r.height})",
        )
      }
    None => abort("节点缺失：\{id}")
  }
}

///|
test "声明文本往返：flex 布局 + 嵌套卡片语义保持" {
  let page = prototype(name="round-trip", width=390.0, height=900.0)
  page.set_layout(flex(direction=@core.Vertical, gap=16.0, padding=24.0))
  page.add(text(id="title", content="欢迎回来", size=28.0, weight="bold"))
  page.add(
    text_input(
      id="username",
      width=@core.Fill,
      height=@core.Fixed(44.0),
      placeholder="用户名",
    ),
  )
  page.add(
    button(
      id="login",
      width=@core.Fill,
      height=@core.Fixed(48.0),
      label="登录",
    ),
  )
  // 嵌套卡片区（绝对层）
  page.add(
    frame(id="card", width=@core.Fixed(342.0), height=@core.Fixed(200.0)),
  )
  let chip = {
    ..rect(id="chip", width=@core.Fixed(120.0), height=@core.Fixed(40.0)),
    x: @core.AlignStart(16.0),
    y: @core.AlignStart(0.0),
    text: "标签",
    style: { ..@core.NodeStyle::default(), fill: "#CCFBF1", },
  }
  page.add_to(parent_id="card", node=chip)

  let text1 = page.to_decl_text()
  assert_true(text1.contains("prototype(name=\"round-trip\""))
  assert_true(
    text1.contains(
      "page.add_to(parent_id=\"card\", node=@decl.generic_node(id=\"chip\",component=\"rect\"",
    ),
  )
  assert_true(
    text1.contains("@decl.flex(direction=@decl.vertical, gap=16, padding=24"),
  )

  let parsed : Prototype = match parse_decl(text1) {
    Ok(p) => p
    Err(e) => abort("往返解析失败：\{e.describe()}")
  }
  let doc = parsed.build()
  // 布局语义在往返后保持一致：按钮在栈内第 3 位
  expect_rect(doc, "login", 24.0, 142.0, 342.0, 48.0)
  assert_eq(@core.validate(doc).length(), 0)
  // 解析后再次序列化 → 文本定点
  assert_eq(parsed.to_decl_text(), text1)
}

///|
test "parse_decl 错误：行号与消息可定位" {
  match
    parse_decl(
      "let page = @decl.prototype(name=\"x\", width=390.0, height=844.0)\nfoo bar",
    ) {
    Ok(_) => assert_true(false)
    Err(e) => {
      assert_eq(e.line, 2)
      assert_true(e.message.contains("无法识别"))
    }
  }
}

///|
test "parse_decl 错误：未知父节点 / 未知组件" {
  match
    parse_decl(
      "let page = @decl.prototype(name=\"x\", width=390.0, height=844.0)\npage.add_to(parent_id=\"nowhere\", node=@decl.frame(id=\"f\", width=@decl.fixed(10.0), height=@decl.fixed(10.0)))",
    ) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.message.contains("unknown_parent"))
  }
  match
    parse_decl(
      "let page = @decl.prototype(name=\"x\", width=390.0, height=844.0)\npage.add(@decl.dialog(id=\"d\"))",
    ) {
    Ok(_) => assert_true(false)
    Err(e) => {
      assert_eq(e.line, 2)
      assert_true(e.message.contains("未知组件"))
    }
  }
}

///|
test "声明文本往返保留 Inspector 可编辑的视觉属性" {
  let page = prototype(name="style-roundtrip", width=390.0, height=844.0)
  let card = {
    ..rect(id="card", width=@core.Fixed(200.0), height=@core.Fixed(120.0)),
    x: @core.AlignStart(24.0),
    y: @core.AlignStart(32.0),
    text: "样式",
    constraint: "stretch-c",
    style: {
      ..@core.NodeStyle::default(),
      fill: "#123456",
      stroke: "#FEDCBA",
      stroke_width: 2.0,
      corner_radius: 18.0,
      opacity: 0.65,
      font_size: 20.0,
      text_color: "#FFFFFF",
      shadow: "e2",
      rotate: 8.0,
      blur: 3.0,
      blend: "multiply",
      line_height: 1.8,
      tracking: 0.12,
      flip: "h",
      font_weight: "bold",
      text_align: "center",
      font_style: "italic",
      stroke_dash: "dashed",
      visible: false,
    },
  }
  page.add(card)
  let source = page.to_decl_text()
  let parsed = match parse_decl(source) {
    Ok(value) => value
    Err(error) => abort(error.describe())
  }
  let doc = parsed.build()
  match doc.get("card") {
    Some(node) => {
      assert_eq(node.style.fill, "#123456")
      assert_eq(node.style.stroke, "#FEDCBA")
      assert_eq(node.style.stroke_width, 2.0)
      assert_eq(node.style.corner_radius, 18.0)
      assert_true(node.style.opacity > 0.649 && node.style.opacity < 0.651)
      assert_eq(node.style.shadow, "e2")
      assert_eq(node.style.rotate, 8.0)
      assert_eq(node.style.blur, 3.0)
      assert_eq(node.style.blend, "multiply")
      assert_true(
        node.style.line_height > 1.799 && node.style.line_height < 1.801,
      )
      assert_true(node.style.tracking > 0.119 && node.style.tracking < 0.121)
      assert_eq(node.style.flip, "h")
      assert_eq(node.style.font_weight, "bold")
      assert_eq(node.style.text_align, "center")
      assert_eq(node.style.font_style, "italic")
      assert_eq(node.style.stroke_dash, "dashed")
      assert_false(node.style.visible)
      assert_eq(node.constraint, "stretch-c")
    }
    None => assert_true(false)
  }
}

///|
test "声明文本往返：三种位置规格 pos_text/pos_val 对称" {
  let page = prototype(name="pos-roundtrip", width=390.0, height=844.0)
  page.add(
    {
      ..rect(id="c", width=@core.Fixed(80.0), height=@core.Fixed(40.0)),
      x: @core.CenterInParent,
      y: @core.AlignEnd(24.0),
    },
  )
  let source = page.to_decl_text()
  assert_true(source.contains("x=@decl.center"))
  assert_true(source.contains("y=@decl.end(24"))
  let parsed : Prototype = match parse_decl(source) {
    Ok(p) => p
    Err(e) => abort("位置规格往返解析失败：\{e.describe()}")
  }
  let doc = parsed.build()
  match doc.get("c") {
    Some(n) =>
      match (n.x, n.y) {
        (@core.CenterInParent, @core.AlignEnd(v)) =>
          assert_true(v > 23.999 && v < 24.001)
        _ => abort("位置规格往返变形")
      }
    None => abort("节点缺失：c")
  }
  // 二次序列化定点：重载后的文档再导出与首轮一致
  assert_eq(parsed.to_decl_text(), source)
  // @decl.start(n) 显式形式与裸数字都归一到 AlignStart，重导出走裸数字
  let src2 = "let page = @decl.prototype(name=\"s\", width=390.0, height=844.0)\npage.add(@decl.rect(id=\"s1\", width=@decl.fixed(40.0), height=@decl.fixed(20.0), x=@decl.start(16), y=8))\n"
  let parsed2 : Prototype = match parse_decl(src2) {
    Ok(p) => p
    Err(e) => abort("start 形式解析失败：\{e.describe()}")
  }
  match parsed2.build().get("s1") {
    Some(n) =>
      match (n.x, n.y) {
        (@core.AlignStart(x), @core.AlignStart(y)) => {
          assert_true(x > 15.999 && x < 16.001)
          assert_true(y > 7.999 && y < 8.001)
        }
        _ => abort("start 形式未归一到 AlignStart")
      }
    None => abort("节点缺失：s1")
  }
  let source2 = parsed2.to_decl_text()
  assert_true(source2.contains("x=16"))
  assert_true(source2.contains("y=8"))
}

///|
test "move_node：人类语义操作修改声明并保持谓词通过" {
  let page = prototype(name="p", width=390.0, height=844.0)
  let a = {
    ..rect(id="a", width=@core.Fixed(100.0), height=@core.Fixed(40.0)),
    x: @core.Fixed(10.0),
    y: @core.Fixed(0.0),
  }
  let b = {
    ..rect(id="b", width=@core.Fixed(100.0), height=@core.Fixed(40.0)),
    x: @core.Fixed(50.0),
    y: @core.Fixed(0.0),
  }
  page.add(a)
  page.add(b)
  assert_eq(page.check().length(), 1)
  let _ = page.move_node(id="b", x=200.0, y=0.0)
  assert_eq(page.check().length(), 0)
  let text = page.to_decl_text()
  assert_true(text.contains("id=\"b\",component=\"rect\""))
  assert_true(text.contains("x=200"))
}

///|
test "canonical 往返：节点文本含单个不配对括号可重载" {
  let page = prototype(name="paren", width=390.0, height=844.0)
  page.add(
    {
      ..rect(id="weird", width=@core.Fixed(100.0), height=@core.Fixed(40.0)),
      text: "(a",
    },
  )
  let decl = page.to_decl_text()
  // decl_escape 把裸 `(` 写成 `\(`
  assert_true(decl.contains("text=\"\\(a\""))
  // 走完整 .mbt.md 装载链：mbt_visual_decl 的括号归并必须转义感知
  let sb = StringBuilder::new()
  sb.write_string("<!-- moonviz:artboard p -->\n```mbt\n")
  sb.write_string("fn visual_p() -> @decl.Prototype {\n")
  for line in lines_of(decl).iter() {
    if line != "" {
      sb.write_string("  " + line + "\n")
    }
  }
  sb.write_string("  page\n}\n```\n")
  match load_mbt_project(sb.to_string()) {
    Ok(m) =>
      match m.project.artboards.get("p") {
        Some(ab) =>
          match ab.doc.get("weird") {
            Some(n) => assert_eq(n.text, "(a")
            None => fail("往返后节点缺失：weird")
          }
        None => fail("往返后画板缺失：p")
      }
    Err(e) => fail("canonical 含不配对括号文本重载失败：\{e}")
  }
}

///|
test "声明文本往返：含引号的容器 id 不损坏" {
  let page = prototype(name="quote-id", width=390.0, height=844.0)
  page.add(
    frame(id="a\"b", width=@core.Fixed(200.0), height=@core.Fixed(100.0)),
  )
  page.add_to(
    parent_id="a\"b",
    node=rect(id="inner", width=@core.Fixed(40.0), height=@core.Fixed(20.0)),
  )
  let source = page.to_decl_text()
  assert_true(source.contains("parent_id=\"a\\\"b\""))
  let parsed : Prototype = match parse_decl(source) {
    Ok(p) => p
    Err(e) => abort("含引号容器 id 往返解析失败：\{e.describe()}")
  }
  let doc = parsed.build()
  match doc.nodes.get("a\"b") {
    Some(parent) =>
      if !parent.children.contains("inner") {
        abort("子节点未挂在含引号的容器下")
      }
    None => abort("容器缺失：a\"b")
  }
  match doc.nodes.get(doc.root_id) {
    Some(root) => assert_false(root.children.contains("inner"))
    None => abort("根节点缺失")
  }
  assert_eq(parsed.to_decl_text(), source)
}

///|
test "声明文本往返：C0 控制符经 \\u00xx 对称还原" {
  let ctrl = "a" + Char::from_int(1).to_string() + "b"
  let page = prototype(name="ctrl", width=390.0, height=844.0)
  page.add(
    {
      ..rect(id="ctl", width=@core.Fixed(80.0), height=@core.Fixed(20.0)),
      text: ctrl,
    },
  )
  let source = page.to_decl_text()
  assert_true(source.contains("\\u0001"))
  let parsed : Prototype = match parse_decl(source) {
    Ok(p) => p
    Err(e) => abort("控制符文本往返解析失败：\{e.describe()}")
  }
  match parsed.build().get("ctl") {
    Some(n) => assert_eq(n.text, ctrl)
    None => abort("节点缺失：ctl")
  }
  assert_eq(parsed.to_decl_text(), source)
}

///|
test "短形式组件：line_height 参数经 apply_decl_style 生效" {
  let src = "let page = @decl.prototype(name=\"t\", width=390.0, height=844.0)\npage.add(@decl.text(id=\"t1\", content=\"hi\", size=16.0, line_height=2.0))\n"
  match parse_decl(src) {
    Ok(p) =>
      match p.build().get("t1") {
        Some(n) =>
          assert_true(
            n.style.line_height > 1.999 && n.style.line_height < 2.001,
          )
        None => abort("节点缺失：t1")
      }
    Err(e) => abort("短形式 line_height 解析失败：\{e.describe()}")
  }
}
