///|
test "render_term：矩形填充 + 文本光栅化 + ANSI 输出" {
  let doc = Document::new({ width: 200.0, height: 100.0 })
  let rect = Node::make("r", Rect)
  let rect = { ..rect, style: { ..rect.style, fill: "#FF0000" } }
  let _ = doc.insert_node(rect, "root")
  let txt = Node::make("tx", Text)
    let txt = { ..txt, x: Fixed(10.0), y: Fixed(40.0), width: Fixed(80.0), height: Fixed(20.0), text: "Hi", style: { ..txt.style, text_color: "#FFFFFF", font_size: 12.0 } }
  let _ = doc.insert_node(txt, "root")
  let out = render_term_svg(doc, surface="#FFFFFF", cols=50)
  // 真彩色 SGR 存在
  assert_true(out.contains("\u{1b}[48;2;255;0;0m"), msg="红底应出现: " + out)
  // 文本字符被绘制（H 与 i 在网格中）
  assert_true(out.contains("H") || out.contains("i"), msg="文本应出现: " + out)
  // 行末 reset
  assert_true(out.contains("\u{1b}[0m"))
}

///|
test "render_term：确定性 + 无节点安全 + 行列上限" {
  let doc = Document::new({ width: 390.0, height: 844.0 })
  let a = render_term_svg(doc, surface="#FFFFFF", cols=40)
  let b = render_term_svg(doc, surface="#FFFFFF", cols=40)
  assert_eq(a, b)
  // 极端纵横比：行数封顶 80
  let tall = Document::new({ width: 100.0, height: 8000.0 })
  let out = render_term_svg(tall, surface="#FFFFFF", cols=40)
  assert_true(out.split("\n").length() <= 82)
}

///|
test "render_term：非 hex 填充不绘制（渐变/none 降级）" {
  let doc = Document::new({ width: 100.0, height: 50.0 })
  let rect = { ..Node::make("g", Rect), style: { ..Node::make("g", Rect).style, fill: "linear:#a:#b@90" } }
  let _ = doc.insert_node(rect, "root")
  let out = render_term_svg(doc, surface="#FFFFFF", cols=40)
  // 渐变 fill 不会被 term_hex_rgb 解析 → 该矩形区域保持 surface 白底（无 255;0;0 之类误绘）
  // 用更直接断言：输出中不应出现除 surface 白色以外的红色系底色——这里渐变两端 #a / #b 无法解析
  assert_false(out.contains("\u{1b}[48;2;10;"), msg="渐变首色 #a 不应被绘制")
  assert_false(out.contains("\u{1b}[48;2;11;"), msg="渐变次色 #b 不应被绘制")
}


///|
test "render_term：节点越出画板底缘不崩溃（修评审 SIGABRT）" {
  let doc = Document::new({ width: 400.0, height: 300.0 })
  let a = { ..Node::make("a", Rect), y: Fixed(290.0), height: Fixed(100.0), style: { ..Node::make("a", Rect).style, fill: "#FF0000", text_color: "#FFFFFF", font_size: 14.0 }, text: "below" }
  let _ = doc.insert_node(a, "root")
  let out = render_term_svg(doc, surface="#FFFFFF", cols=100)
  assert_true(out.length() > 0)
}

///|
test "render_term：栈布局节点溢出画板底缘不崩溃（评分代理复现路径）" {
  let doc = Document::new({ width: 400.0, height: 300.0 })
  let _ = doc.update_node("root", fn(r) { { ..r, layout: Some({ dir: Vertical, gap: 0.0, justify: Start, padding: Padding::uniform(0.0) }) } })
  for i in 0..<5 {
    let n = { ..Node::make("n\{i}", Rect), height: Fixed(100.0), width: Fixed(400.0), y: AlignStart((i * 100).to_double()), text: "行\{i}", style: { ..Node::make("n\{i}", Rect).style, fill: "#EEEEEE", text_color: "#111111", font_size: 14.0 } }
    let _ = doc.insert_node(n, "root")
  }
  let out = render_term_svg(doc, surface="#FFFFFF", cols=100)
  assert_true(out.length() > 0)
}


///|
test "render_term：数据绑定解析 + 隐藏子树不绘制（语义与 SVG 面对齐）" {
  let doc = Document::new({ width: 200.0, height: 100.0 })
  let txt = { ..Node::make("tx", Text), x: Fixed(10.0), y: Fixed(30.0), width: Fixed(80.0), height: Fixed(20.0), text: "{{user.name}}", style: { ..Node::make("tx", Text).style, text_color: "#1A1C1E", font_size: 14.0 } }
  let _ = doc.insert_node(txt, "root")
  let hidden = { ..Node::make("hid", Rect), x: Fixed(10.0), y: Fixed(60.0), width: Fixed(50.0), height: Fixed(20.0), style: { ..Node::make("hid", Rect).style, fill: "#FF0000", visible: false } }
  let _ = doc.insert_node(hidden, "root")
  // 无数据：字面占位
  let out1 = render_term_svg(doc, surface="#FFFFFF", cols=40)
  assert_true(out1.contains("{{user.name}}"), msg="无数据应字面占位")
  // 注入数据后应解析
  let inner : Map[String, DataValue] = Map::new()
  inner.set("name", DStr("林一"))
  let user_obj : Map[String, DataValue] = Map::new()
  user_obj.set("user", DObj(inner))
  let d2 : DataValue = DObj(user_obj)
  let out2 = render_term_svg(doc, surface="#FFFFFF", cols=40, data=d2)
  assert_true(out2.contains("林一"), msg="数据绑定应解析: " + out2)
  assert_false(out2.contains("{{user.name}}"), msg="解析后不应残留占位")
  // 隐藏节点不绘制
  assert_false(out2.contains("\u{1b}[48;2;255;0;0m"), msg="隐藏红块不应出现")
}
