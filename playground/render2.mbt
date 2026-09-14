///|
/// 增强像素画布：抗锯齿（2x 超采样）+ 圆角矩形 + 5×7 位图字体 + DEFLATE 压缩。
///
/// 渲染管线：Document → layout → 高分辨率 RGBA → downscale → DEFLATE PNG。
/// 输出比 store-mode 小 5-20 倍，且边缘平滑、有文字标注、圆角柔和。

// ---------------------------------------------------------------------------
// 高分辨率 RGBA 帧缓冲（2x 超采样 → 内部像素密度 = 2）
// ---------------------------------------------------------------------------

struct HiResBuf {
  width : Int // 最终输出宽
  height : Int
  ss : Int // 超采样倍率（当前固定 2）
  pixels : FixedArray[Int] // ARGB，尺寸 = (width*ss) * (height*ss)
}

///|
fn hires_new(width : Int, height : Int) -> HiResBuf {
  let ss = 2
  {
    width,
    height,
    ss,
    pixels: FixedArray::make(width * ss * height * ss, 0xFF000000),
  }
}

///|
fn hires_set(buf : HiResBuf, x : Int, y : Int, argb : Int) -> Unit {
  let w = buf.width * buf.ss
  if x >= 0 && x < w && y >= 0 && y < buf.height * buf.ss {
    buf.pixels[y * w + x] = argb
  }
}

///|
fn hires_get(buf : HiResBuf, x : Int, y : Int) -> Int {
  let w = buf.width * buf.ss
  if x >= 0 && x < w && y >= 0 && y < buf.height * buf.ss {
    buf.pixels[y * w + x]
  } else {
    0xFF000000
  }
}

// ---------------------------------------------------------------------------
// 抗锯齿 downsample（box filter 2x2 → 1x）
// ---------------------------------------------------------------------------

///|
fn downsample(buf : HiResBuf) -> RgbaBuf {
  let out = rgba_new(buf.width, buf.height)
  for y in 0..<buf.height {
    for x in 0..<buf.width {
      let p00 = hires_get(buf, x * 2, y * 2)
      let p01 = hires_get(buf, x * 2 + 1, y * 2)
      let p10 = hires_get(buf, x * 2, y * 2 + 1)
      let p11 = hires_get(buf, x * 2 + 1, y * 2 + 1)
      let avg = avg4(p00, p01, p10, p11)
      rgba_set(out, x, y, avg)
    }
  }
  out
}

///|
fn avg4(a : Int, b : Int, c : Int, d : Int) -> Int {
  let r = (
      ((a >> 16) & 0xFF) +
      ((b >> 16) & 0xFF) +
      ((c >> 16) & 0xFF) +
      ((d >> 16) & 0xFF)
    ) /
    4
  let g = (
      ((a >> 8) & 0xFF) +
      ((b >> 8) & 0xFF) +
      ((c >> 8) & 0xFF) +
      ((d >> 8) & 0xFF)
    ) /
    4
  let bl = ((a & 0xFF) + (b & 0xFF) + (c & 0xFF) + (d & 0xFF)) / 4
  0xFF000000 + (r << 16) + (g << 8) + bl
}

// ---------------------------------------------------------------------------
// 圆角矩形（超采样坐标系下逐像素填充）
// ---------------------------------------------------------------------------

///|
fn fill_rounded_rect(
  buf : HiResBuf,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  argb : Int,
) -> Unit {
  let ss = buf.ss.to_double()
  let x0 = (x * ss).to_int()
  let y0 = (y * ss).to_int()
  let x1 = ((x + w) * ss).to_int()
  let y1 = ((y + h) * ss).to_int()
  let r = (radius * ss).to_int()
  for yy in y0..<y1 {
    for xx in x0..<x1 {
      if in_rounded_rect(xx - x0, yy - y0, x1 - x0, y1 - y0, r) {
        hires_set(buf, xx, yy, argb)
      }
    }
  }
}

///|
fn in_rounded_rect(px : Int, py : Int, w : Int, h : Int, r : Int) -> Bool {
  if r <= 0 {
    return true
  }
  let r = if r * 2 > w { w / 2 } else if r * 2 > h { h / 2 } else { r }
  // 四角检查
  let cx = if px < r { r } else if px > w - r { w - r } else { px }
  let cy = if py < r { r } else if py > h - r { h - r } else { py }
  let dx = px - cx
  let dy = py - cy
  dx * dx + dy * dy <= r * r
}

///|
fn stroke_rounded_rect(
  buf : HiResBuf,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  argb : Int,
) -> Unit {
  let ss = buf.ss.to_double()
  let x0 = (x * ss).to_int()
  let y0 = (y * ss).to_int()
  let x1 = ((x + w) * ss).to_int()
  let y1 = ((y + h) * ss).to_int()
  let r = (radius * ss).to_int()
  let bw = x1 - x0
  let bh = y1 - y0
  let r = if r * 2 > bw { bw / 2 } else if r * 2 > bh { bh / 2 } else { r }
  for yy in y0..<y1 {
    for xx in x0..<x1 {
      let px = xx - x0
      let py = yy - y0
      let cx = if px < r { r } else if px > bw - r { bw - r } else { px }
      let cy = if py < r { r } else if py > bh - r { bh - r } else { py }
      let dx = px - cx
      let dy = py - cy
      let dist2 = dx * dx + dy * dy
      let outer = r + 2 // 边框厚度（超采样像素）
      let inner = r - 2
      if r <= 0 {
        // 直角：只画边缘
        if px <= 2 || px >= bw - 3 || py <= 2 || py >= bh - 3 {
          hires_set(buf, xx, yy, argb)
        }
      } else if dist2 <= outer * outer && dist2 >= inner * inner {
        hires_set(buf, xx, yy, argb)
      } else if r <= 2 && (px <= 1 || px >= bw - 2 || py <= 1 || py >= bh - 2) {
        hires_set(buf, xx, yy, argb)
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 5×7 位图字体（ASCII 32–126 的核心字符）
// ---------------------------------------------------------------------------

///|
fn font_a() -> FixedArray[Int] {
  [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11] // A
}

///|
fn font_b() -> FixedArray[Int] {
  [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E] // B
}

///|
fn font_c() -> FixedArray[Int] {
  [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E] // C
}

///|
fn font_d() -> FixedArray[Int] {
  [0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C] // D
}

///|
fn font_e() -> FixedArray[Int] {
  [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F] // E
}

///|
fn font_f() -> FixedArray[Int] {
  [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10] // F
}

///|
fn font_g() -> FixedArray[Int] {
  [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0E] // G
}

///|
fn font_h() -> FixedArray[Int] {
  [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11] // H
}

///|
fn font_i() -> FixedArray[Int] {
  [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E] // I
}

///|
fn font_j() -> FixedArray[Int] {
  [0x01, 0x01, 0x01, 0x01, 0x01, 0x11, 0x0E] // J
}

///|
fn font_k() -> FixedArray[Int] {
  [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11] // K
}

///|
fn font_l() -> FixedArray[Int] {
  [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F] // L
}

///|
fn font_m() -> FixedArray[Int] {
  [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11] // M
}

///|
fn font_n() -> FixedArray[Int] {
  [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11] // N
}

///|
fn font_o() -> FixedArray[Int] {
  [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E] // O
}

///|
fn font_p() -> FixedArray[Int] {
  [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10] // P
}

///|
fn font_q() -> FixedArray[Int] {
  [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D] // Q
}

///|
fn font_r() -> FixedArray[Int] {
  [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11] // R
}

///|
fn font_s() -> FixedArray[Int] {
  [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E] // S
}

///|
fn font_t() -> FixedArray[Int] {
  [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04] // T
}

///|
fn font_u() -> FixedArray[Int] {
  [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E] // U
}

///|
fn font_v() -> FixedArray[Int] {
  [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04] // V
}

///|
fn font_w() -> FixedArray[Int] {
  [0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11] // W
}

///|
fn font_x() -> FixedArray[Int] {
  [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11] // X
}

///|
fn font_y() -> FixedArray[Int] {
  [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04] // Y
}

///|
fn font_z() -> FixedArray[Int] {
  [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F] // Z
}

///|
fn font_0() -> FixedArray[Int] {
  [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E] // 0
}

///|
fn font_1() -> FixedArray[Int] {
  [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E] // 1
}

///|
fn font_2() -> FixedArray[Int] {
  [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F] // 2
}

///|
fn font_3() -> FixedArray[Int] {
  [0x0E, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0E] // 3
}

///|
fn font_4() -> FixedArray[Int] {
  [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02] // 4
}

///|
fn font_5() -> FixedArray[Int] {
  [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E] // 5
}

///|
fn font_6() -> FixedArray[Int] {
  [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E] // 6
}

///|
fn font_7() -> FixedArray[Int] {
  [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08] // 7
}

///|
fn font_8() -> FixedArray[Int] {
  [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E] // 8
}

///|
fn font_9() -> FixedArray[Int] {
  [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C] // 9
}

///|
/// ASCII → 5 位行编码（7 行）
fn glyph_of(c : Char) -> FixedArray[Int]? {
  match c {
    'A' => Some(font_a())
    'B' => Some(font_b())
    'C' => Some(font_c())
    'D' => Some(font_d())
    'E' => Some(font_e())
    'F' => Some(font_f())
    'G' => Some(font_g())
    'H' => Some(font_h())
    'I' => Some(font_i())
    'J' => Some(font_j())
    'K' => Some(font_k())
    'L' => Some(font_l())
    'M' => Some(font_m())
    'N' => Some(font_n())
    'O' => Some(font_o())
    'P' => Some(font_p())
    'Q' => Some(font_q())
    'R' => Some(font_r())
    'S' => Some(font_s())
    'T' => Some(font_t())
    'U' => Some(font_u())
    'V' => Some(font_v())
    'W' => Some(font_w())
    'X' => Some(font_x())
    'Y' => Some(font_y())
    'Z' => Some(font_z())
    '0' => Some(font_0())
    '1' => Some(font_1())
    '2' => Some(font_2())
    '3' => Some(font_3())
    '4' => Some(font_4())
    '5' => Some(font_5())
    '6' => Some(font_6())
    '7' => Some(font_7())
    '8' => Some(font_8())
    '9' => Some(font_9())
    _ => None
  }
}

///|
/// 在超采样坐标画一段文字（5×7 位图，每字符间隔 1 列）
fn draw_text_hires(
  buf : HiResBuf,
  text : String,
  x : Double,
  y : Double,
  argb : Int,
) -> Unit {
  let ss = buf.ss.to_double()
  let bx = (x * ss).to_int()
  let by = (y * ss).to_int()
  let scale = buf.ss // 字体缩放 = ss（最终输出中 5×7 → 10×14 有效像素）
  for ci in 0..<text.length() {
    match text.get_char(ci) {
      Some(c) =>
        match glyph_of(c) {
          Some(glyph) =>
            for row in 0..<7 {
              for col in 0..<5 {
                let bit = (glyph[row] >> (4 - col)) & 1
                if bit == 1 {
                  for sy in 0..<scale {
                    for sx in 0..<scale {
                      hires_set(
                        buf,
                        bx + ci * 6 * scale + col * scale + sx,
                        by + row * scale + sy,
                        argb,
                      )
                    }
                  }
                }
              }
            }
          None => ()
        }
      None => ()
    }
  }
}

// ---------------------------------------------------------------------------
// 主渲染入口：Document → 高分辨率 RGBA → downsample → DEFLATE PNG
// ---------------------------------------------------------------------------

///|
pub fn render_png_hires(
  doc : @core.Document,
  width : Int,
  height : Int,
) -> Array[Byte] {
  let layout = @core.solve(doc)
  let buf = hires_new(width, height)
  let ss = buf.ss.to_double()

  // 白底
  fill_rounded_rect(
    buf,
    0.0,
    0.0,
    width.to_double(),
    height.to_double(),
    0.0,
    color_from_hex("#F8F9FB"),
  )

  // 树序遍历渲染
  render_node_hires(buf, doc, doc.root_id, layout, ss)
  let down = downsample(buf)
  png_encode_deflate(down)
}

///|
fn render_node_hires(
  buf : HiResBuf,
  doc : @core.Document,
  id : String,
  layout : @core.SolvedLayout,
  ss : Double,
) -> Unit {
  match doc.nodes.get(id) {
    None => ()
    Some(n) =>
      match layout.rect_of(id) {
        None => ()
        Some(r) => {
          let fill_hex : String = if n.style.fill == "none" {
            ""
          } else {
            n.style.fill
          }
          let radius = n.style.corner_radius
          // 填充
          if fill_hex != "" && fill_hex != "#FFFFFF" {
            fill_rounded_rect(
              buf,
              r.x,
              r.y,
              r.width,
              r.height,
              radius,
              color_from_hex(fill_hex),
            )
          }
          // 边框
          let border_c : Int = if n.style.stroke != "none" {
            color_from_hex(n.style.stroke)
          } else {
            color_from_hex("#C8CDD6")
          }
          stroke_rounded_rect(
            buf,
            r.x,
            r.y,
            r.width,
            r.height,
            radius,
            border_c,
          )
          // 文字（取 id 的大写首字母段或 n.text 的 ASCII 部分）
          let label : String = if n.text != "" {
            ascii_only(n.text)
          } else {
            ascii_only(n.id)
          }
          if label != "" {
            let tx = r.x + 8.0
            let ty = r.y + 4.0
            let tc : Int = if fill_hex != "" && is_dark_hex(fill_hex) {
              color_from_hex("#FFFFFF")
            } else {
              color_from_hex("#333333")
            }
            draw_text_hires(buf, label, tx, ty, tc)
          }
          for cid in n.children.iter() {
            render_node_hires(buf, doc, cid, layout, ss)
          }
        }
      }
  }
}

///|
fn ascii_only(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    let code = c.to_int()
    if code >= 32 && code <= 126 {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn is_dark_hex(hex : String) -> Bool {
  match rgb_of(hex) {
    None => false
    Some((r, g, b)) => (r + g + b) / 3 < 128
  }
}

// ---------------------------------------------------------------------------
// DEFLATE 压缩版 PNG 编码
// ---------------------------------------------------------------------------

///|
fn png_encode_deflate(buf : RgbaBuf) -> Array[Byte] {
  let out : Array[Byte] = []
  // 签名
  push_b(out, 137)
  push_b(out, 80)
  push_b(out, 78)
  push_b(out, 71)
  push_b(out, 13)
  push_b(out, 10)
  push_b(out, 26)
  push_b(out, 10)

  // IHDR
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

  // 原始扫描线
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

  // DEFLATE 压缩
  let raw_bytes = Bytes::from_iter(raw.iter())
  let compressed = deflate_compress_fixed_v(raw_bytes)

  // zlib 包装（2 字节头 + deflate + 4 字节 adler）
  let zlib : Array[Byte] = []
  push_b(zlib, 0x78)
  push_b(zlib, 0x01)
  for i in 0..<compressed.length() {
    match compressed.get(i) {
      Some(b) => zlib.push(b)
      None => ()
    }
  }
  push_be32(zlib, adler32(raw))

  let idat = png_chunk("IDAT", zlib)
  for x in idat.iter() {
    out.push(x)
  }

  // IEND
  let iend = png_chunk("IEND", [])
  for x in iend.iter() {
    out.push(x)
  }
  out
}
