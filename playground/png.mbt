///|
/// 纯 MoonBit PNG 像素画布：渲染计划 → RGBA 位图 → PNG 字节流。
/// 借用 std 的 @base64 作为文本面；配合 native 目标可以直接打开。
struct RgbaBuf {
  width : Int
  height : Int
  pixels : FixedArray[Int] // ARGB
}

///|
fn rgba_new(width : Int, height : Int) -> RgbaBuf {
  { width, height, pixels: FixedArray::make(width * height, 0xFF000000) }
}

///|
fn rgba_set(buf : RgbaBuf, x : Int, y : Int, argb : Int) -> Unit {
  if x >= 0 && x < buf.width && y >= 0 && y < buf.height {
    buf.pixels[y * buf.width + x] = argb
  }
}

///|
fn fill_rect_rgba(
  buf : RgbaBuf,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  argb : Int,
) -> Unit {
  let x0 = if x < 0 { 0 } else { x }
  let y0 = if y < 0 { 0 } else { y }
  let x1 = if x + w > buf.width { buf.width } else { x + w }
  let y1 = if y + h > buf.height { buf.height } else { y + h }
  for yy in y0..<y1 {
    for xx in x0..<x1 {
      rgba_set(buf, xx, yy, argb)
    }
  }
}

///|
fn stroke_rect_rgba(
  buf : RgbaBuf,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  argb : Int,
) -> Unit {
  let x1 = if x + w > buf.width { buf.width } else { x + w }
  let y1 = if y + h > buf.height { buf.height } else { y + h }
  for xx in x..<x1 {
    rgba_set(buf, xx, y, argb)
    rgba_set(buf, xx, y1 - 1, argb)
  }
  for yy in y..<y1 {
    rgba_set(buf, x, yy, argb)
    rgba_set(buf, x1 - 1, yy, argb)
  }
}

///|
fn has_pref(s : String, prefix : String) -> Bool {
  s.length() >= prefix.length() &&
  s.substring(start=0, end=prefix.length()) == prefix
}

///|
fn hex_digit_c(s : String, i : Int) -> Int? {
  match s.get_char(i) {
    Some(c) => hex_digit(c)
    None => None
  }
}

///|
fn hex_digit(c : Char) -> Int? {
  let code = c.to_int()
  if code >= 48 && code <= 57 {
    Some(code - 48)
  } else if code >= 97 && code <= 102 {
    Some(code - 87)
  } else if code >= 65 && code <= 70 {
    Some(code - 55)
  } else {
    None
  }
}

///|
fn hex2(s : String, i : Int) -> Int {
  let a = match hex_digit_c(s, i) {
    Some(x) => x
    None => 0
  }
  let b = match hex_digit_c(s, i + 1) {
    Some(x) => x
    None => 0
  }
  a * 16 + b
}

///|
fn color_from_hex(hex : String) -> Int {
  let body = if has_pref(hex, "#") { hex.substring(start=1) } else { hex }
  0xFF000000 + (hex2(body, 0) << 16) + (hex2(body, 2) << 8) + hex2(body, 4)
}

///|
fn push_b(arr : Array[Byte], v : Int) -> Unit {
  arr.push((v & 0xFF).to_byte())
}

///|
fn push_be32(arr : Array[Byte], v : Int) -> Unit {
  push_b(arr, (v >> 24) & 0xFF)
  push_b(arr, (v >> 16) & 0xFF)
  push_b(arr, (v >> 8) & 0xFF)
  push_b(arr, v & 0xFF)
}

///|
fn push_tag(arr : Array[Byte], tag : String) -> Unit {
  for i in 0..<tag.length() {
    match tag.get_char(i) {
      Some(c) => push_b(arr, c.to_int())
      None => ()
    }
  }
}

///|
/// CRC32-IEEE：UInt 语义，poly 0xEDB88320；（初始 0xFFFFFFFF>xor-final）
fn crc32(data : Array[Byte], start : Int, len : Int) -> Int {
  // 64 位承载 32 位 CRC 位模式，避免有符号溢出与算术右移
  let crc = crc32_data(data, start, len)
  let fin : Int64 = crc ^ 4294967295L
  fin.to_int()
}

///|
fn crc32_data(data : Array[Byte], start : Int, len : Int) -> Int64 {
  let mut crc : Int64 = 4294967295L
  let poly : Int64 = 3988292384L // 0xEDB88320
  for i in 0..<len {
    let b0 = match data.get(start + i) {
      Some(b) => b.to_int().to_int64()
      None => 0L
    }
    crc = crc ^ (b0 & 255L)
    for _bit in 0..<8 {
      if (crc & 1L) == 1L {
        crc = (crc >> 1) ^ poly
      } else {
        crc = crc >> 1
      }
    }
  }
  crc
}

///|
fn adler32(data : Array[Byte]) -> Int {
  let mut a = 1
  let mut b = 0
  for i in 0..<data.length() {
    let byte0 = match data.get(i) {
      Some(x) => x.to_int() & 0xFF
      None => 0
    }
    a = (a + byte0) % 65521
    b = (b + a) % 65521
  }
  (b << 16) + a
}

///|
fn zlib_store(data : Array[Byte]) -> Array[Byte] {
  let out : Array[Byte] = []
  push_b(out, 0x78)
  push_b(out, 0x01)
  let n : Int = if data.length() == 0 {
    1
  } else {
    (data.length() + 65534) / 65535
  }
  for i in 0..<n {
    let st = i * 65535
    let en = if st + 65535 > data.length() { data.length() } else { st + 65535 }
    let sz = en - st
    let final_flag = if i == n - 1 { 1 } else { 0 }
    push_b(out, final_flag)
    push_b(out, sz % 256)
    push_b(out, (sz >> 8) & 0xFF)
    push_b(out, (0xFFFF - sz) & 0xFF)
    push_b(out, ((0xFFFF - sz) >> 8) & 0xFF)
    for k in st..<en {
      match data.get(k) {
        Some(x) => out.push(x)
        None => ()
      }
    }
  }
  push_be32(out, adler32(data))
  out
}

///|
fn png_chunk(tag : String, data : Array[Byte]) -> Array[Byte] {
  let body : Array[Byte] = []
  push_tag(body, tag)
  for x in data.iter() {
    body.push(x)
  }
  let out : Array[Byte] = []
  push_be32(out, data.length())
  for x in body.iter() {
    out.push(x)
  }
  push_be32(out, crc32(body, 0, body.length()))
  out
}

///|
pub fn png_encode(buf : RgbaBuf) -> Array[Byte] {
  let out : Array[Byte] = []
  push_b(out, 137)
  push_b(out, 80)
  push_b(out, 78)
  push_b(out, 71)
  push_b(out, 13)
  push_b(out, 10)
  push_b(out, 26)
  push_b(out, 10)

  let ihdr : Array[Byte] = []
  push_be32(ihdr, buf.width)
  push_be32(ihdr, buf.height)
  push_b(ihdr, 8)
  push_b(ihdr, 6)
  push_b(ihdr, 0)
  push_b(ihdr, 0)
  push_b(ihdr, 0)
  let ihdr_chunk = png_chunk("IHDR", ihdr)
  for x in ihdr_chunk.iter() {
    out.push(x)
  }

  let raw : Array[Byte] = []
  for y in 0..<buf.height {
    push_b(raw, 0)
    for x in 0..<buf.width {
      let px = buf.pixels[y * buf.width + x]
      push_b(raw, (px >> 16) & 0xFF)
      push_b(raw, (px >> 8) & 0xFF)
      push_b(raw, px & 0xFF)
      push_b(raw, (px >> 24) & 0xFF)
    }
  }
  let idat = zlib_store(raw)
  for x in png_chunk("IDAT", idat).iter() {
    out.push(x)
  }

  let iend = png_chunk("IEND", [])
  for x in iend.iter() {
    out.push(x)
  }
  out
}

///|
fn base64_encode(data : Array[Byte]) -> String {
  let bytes = Bytes::from_iter(data.iter())
  @base64.encode(bytes)
}

///|
pub fn render_png(
  doc : @core.Document,
  width : Int,
  height : Int,
) -> Array[Byte] {
  let layout = @core.solve(doc)
  let buf = rgba_new(width, height)
  fill_rect_rgba(buf, 0, 0, width, height, color_from_hex("#FFFFFF"))
  walk_png(buf, doc, doc.root_id, layout)
  png_encode(buf)
}

///|
fn walk_png(
  buf : RgbaBuf,
  doc : @core.Document,
  id : String,
  layout : @core.SolvedLayout,
) -> Unit {
  match doc.nodes.get(id) {
    None => ()
    Some(n) =>
      match layout.rect_of(id) {
        None => ()
        Some(r) => {
          let fill_hex : String = if n.style.fill == "none" {
            "#FFFFFF"
          } else {
            n.style.fill
          }
          fill_rect_rgba(
            buf,
            r.x.to_int(),
            r.y.to_int(),
            r.width.to_int(),
            r.height.to_int(),
            color_from_hex(fill_hex),
          )
          stroke_rect_rgba(
            buf,
            r.x.to_int(),
            r.y.to_int(),
            r.width.to_int(),
            r.height.to_int(),
            color_from_hex("#CCCCCC"),
          )
          for cid in n.children.iter() {
            walk_png(buf, doc, cid, layout)
          }
        }
      }
  }
}
