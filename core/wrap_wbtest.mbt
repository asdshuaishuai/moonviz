///|
test "wrap_line_at_width 拉丁整词断行" {
  let r : Array[String] = wrap_line_at_width(
    "The quick brown fox jumps over the lazy dog",
    12.857,
  )
  assert_eq(r.length(), 2)
  assert_eq(r[0], "The quick brown fox jumps")
  assert_eq(r[1], "over the lazy dog")
}

///|
test "wrap_line_at_width CJK 逐字断行" {
  let r : Array[String] = wrap_line_at_width("这是一段比较长的中文文本内容用于验证", 12.857)
  assert_eq(r.length(), 2)
  assert_eq(r[0], "这是一段比较长的中文文本")
  assert_eq(r[1], "内容用于验证")
}

///|
test "wrap_line_at_width 短文本不换行" {
  let r : Array[String] = wrap_line_at_width("short", 12.857)
  assert_eq(r.length(), 1)
  assert_eq(r[0], "short")
}

///|
test "wrap_line_at_width 超长不可断词硬拆" {
  // 20 个 CJK 字，max 5em → 5/5/5/5 四行
  let text = "一二三四五六七八九十甲乙丙丁戊己庚辛壬癸"
  let r : Array[String] = wrap_line_at_width(text, 5.0)
  assert_eq(r.length(), 4)
  assert_eq(r[0], "一二三四五")
  assert_eq(r[3], "己庚辛壬癸")
}

///|
test "wrap_text_lines 硬换行与宽度换行组合" {
  // 两段硬换行，第二段超宽再二次换行
  let r : Array[String] = wrap_text_lines("AB\n这是一段会被宽度限制的中文长文本内容", 14.0, 70.0)
  // 70/14 = 5em → 中文段 19 字 → 5/5/5/4
  assert_true(r.length() >= 4)
  assert_eq(r[0], "AB")
}

///|
test "wrap_text_lines 空文本安全" {
  let r : Array[String] = wrap_text_lines("", 14.0, 100.0)
  assert_eq(r.length(), 1)
  assert_eq(r[0], "")
}
