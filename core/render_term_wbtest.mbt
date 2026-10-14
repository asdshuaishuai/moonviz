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
