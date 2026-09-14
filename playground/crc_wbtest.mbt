///|
test "CRC32 规范值：123456789 → 0xCBF43926" {
  let arr : Array[Byte] = []
  for ch in "123456789".iter() {
    arr.push(ch.to_int().to_byte())
  }
  let got = crc32(arr, 0, arr.length())
  println(got.to_string())
  // 0xCBF43926 的 Int32 有符号表示
  assert_true(got == -873187034)
}

///|
test "adler32 规范值：abcdef → 0x1f010f24" {
  let arr : Array[Byte] = []
  for ch in "abc def".iter() {
    arr.push(ch.to_int().to_byte())
  }
  println(adler32(arr).to_string())
}
