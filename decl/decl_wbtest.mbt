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
    style: { ..@core.NodeStyle::default(), fill: "#CCFBF1" },
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
      assert_eq(node.constraint, "stretch-c")
    }
    None => assert_true(false)
  }
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
