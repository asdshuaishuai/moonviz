///|
test "fit_font_size 溢出等比缩" {
  // 19 字 CJK、宽 70、高 21：preferred 14 → 5字/行×4行×21=84 > 21 → 缩到 8 下限附近
  let f = fit_font_size("这是一段比较长的中文文本内容用于验证", 14.0, 70.0, 21.0, 1.5, "shrink")
  assert_true(f < 14.0)
  assert_true(f >= 8.0)
  // 缩放后实际渲染不溢出
  let lines = wrap_text_lines("这是一段比较长的中文文本内容用于验证", f, 70.0)
  assert_true(lines.length().to_double() * f * 1.5 <= 21.0 + 0.01 || f == 8.0)
}

///|
test "fit_font_size 单行留白放大（auto）" {
  // 标题 24px 在 320x120 hero 槽位：高余量 → 放大，宽度与 2x 封顶
  let f = fit_font_size("MoonViz", 24.0, 320.0, 120.0, 1.5, "auto")
  assert_true(f > 24.0)
  assert_true(f <= 48.0)
  // 放大后宽度仍不溢出
  assert_true(f * text_em_width("MoonViz") <= 320.0)
  // shrink 模式同样的槽位不放大
  let f2 = fit_font_size("MoonViz", 24.0, 320.0, 120.0, 1.5, "shrink")
  assert_eq(f2, 24.0)
}

///|
test "fit_font_size 已贴合不放大不缩小" {
  // 文本恰好占满宽度时不放大
  let f = fit_font_size("一二三四五", 14.0, 70.0, 21.0, 1.5, "auto")
  assert_eq(f, 14.0)
}

///|
test "fit_font_size 退化参数安全" {
  assert_eq(fit_font_size("", 14.0, 100.0, 50.0, 1.5, "auto"), 14.0)
  assert_eq(fit_font_size("text", 0.0, 100.0, 50.0, 1.5, "auto"), 0.0)
  assert_eq(fit_font_size("text", 14.0, 0.0, 50.0, 1.5, "auto"), 14.0)
  assert_eq(fit_font_size("text", 14.0, 100.0, 0.0, 1.5, "auto"), 14.0)
}
