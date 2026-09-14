///|
test "PNG 编码：签名与 IHDR 可校验" {
  let doc = @core.Document::sample_login()
  let bytes = render_png(doc, 390, 844)
  assert_true(bytes.length() > 64)
  // 8 字节签名
  assert_true(bytes.get(0) == Some(Int::to_byte(137)))
  assert_true(bytes.get(1) == Some(Int::to_byte(80)))
  assert_true(bytes.get(2) == Some(Int::to_byte(78)))
  assert_true(bytes.get(3) == Some(Int::to_byte(71)))
  // IHDR 宽高（字节 16-19 = width 390=0x186，20-23 = height 844=0x34C）
  assert_true(
    bytes.get(18) == Some(Int::to_byte(1)) &&
    bytes.get(19) == Some(Int::to_byte(134)),
  )
}
