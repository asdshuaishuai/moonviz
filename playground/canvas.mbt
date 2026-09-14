///|
/// MoonBit 终端画布（playground 宿主层，纯 MoonBit，wasm-gc/native/js 均可编译）。
///
/// 组成：
/// - Camera：视口（平移/缩放）与屏幕字符坐标 ↔ 世界坐标变换
/// - ScreenBuf：字符栅格（每格 = 字符 + ANSI 前缀）
/// - draw_document：Document → 栅格（树序：容器先画、子节点覆盖）
/// - pick_at：屏幕 → 世界 → 最上层节点（供拖拽命令）
///
/// 拖拽坐标先经相机逆变换，再交给引擎会话协议（handle_human）。
pub(all) struct Camera {
  mut pan_x : Double
  mut pan_y : Double
  mut zoom : Double // 1 屏幕列 = zoom 个世界像素；行高为列宽的 2 倍
}

///|
pub fn Camera::new() -> Camera {
  { pan_x: 0.0, pan_y: 0.0, zoom: 1.0 }
}

///|
pub fn camera_zoom_in(c : Camera) -> Unit {
  if c.zoom < 4.0 {
    c.zoom = c.zoom * 2.0
  }
}

///|
pub fn camera_zoom_out(c : Camera) -> Unit {
  if c.zoom > 0.125 {
    c.zoom = c.zoom / 2.0
  }
}

///|
pub fn camera_pan(c : Camera, dx : Double, dy : Double) -> Unit {
  c.pan_x = c.pan_x + dx
  c.pan_y = c.pan_y + dy
}

///|
struct CamView {
  sx : Double
  sy : Double
}

///|
fn to_screen_f(c : Camera, wx : Double, wy : Double) -> CamView {
  { sx: (wx - c.pan_x) * c.zoom, sy: (wy - c.pan_y) * c.zoom / 2.0 }
}

///|
fn to_world_f(c : Camera, col : Double, row : Double) -> (Double, Double) {
  (col / c.zoom + c.pan_x, row * 2.0 / c.zoom + c.pan_y)
}

// ---------------------------------------------------------------------------
// 字符栅格
// ---------------------------------------------------------------------------

///|
struct Cell {
  ch : Char
  color : String // ANSI 前缀；"" = 默认前景
}

///|
struct ScreenBuf {
  cols : Int
  rows : Int
  cells : Array[Cell]
}

///|
fn screen_new(cols : Int, rows : Int) -> ScreenBuf {
  let cells : Array[Cell] = Array::new()
  let total = cols * rows
  let mut i = 0
  let total = cols * rows
  while i < total {
    cells.push({ ch: ' ', color: "" })
    i = i + 1
  }
  { cols, rows, cells }
}

///|
fn screen_set(
  s : ScreenBuf,
  col : Int,
  row : Int,
  ch : Char,
  color : String,
) -> Unit {
  if col >= 0 && col < s.cols && row >= 0 && row < s.rows {
    s.cells[row * s.cols + col] = { ch, color }
  }
}

///|
fn screen_char_at(s : ScreenBuf, col : Int, row : Int) -> Char? {
  if col >= 0 && col < s.cols && row >= 0 && row < s.rows {
    Some(s.cells[row * s.cols + col].ch)
  } else {
    None
  }
}

///|
fn screen_render(s : ScreenBuf) -> String {
  let sb = StringBuilder::new()
  for row in 0..<s.rows {
    for col in 0..<s.cols {
      let cell = s.cells[row * s.cols + col]
      if cell.color == "" {
        sb.write_char(cell.ch)
      } else {
        sb.write_string(cell.color)
        sb.write_char(cell.ch)
        sb.write_string("\u{1b}[39m")
      }
    }
    sb.write_char('\n')
  }
  sb.to_string()
}

///|
/// 清屏 + 光标复位 + 画栅格内容（重绘一次画布的完整 ANSI 输出）
pub fn frame_of(s : ScreenBuf) -> String {
  "\u{1b}[2J\u{1b}[H" + screen_render(s)
}

// ---------------------------------------------------------------------------
// 颜色
// ---------------------------------------------------------------------------

///|
const ANSI_BORDER : String = "\u{1b}[90m"

///|
const ANSI_ALERT : String = "\u{1b}[91m"

///|
const ANSI_LABEL_DARK : String = "\u{1b}[37m"

///|
const ANSI_LABEL_LIGHT : String = "\u{1b}[97m"

///|
fn rgb_of(hex : String) -> (Int, Int, Int)? {
  let body = if has_pref(hex, "#") { hex.substring(start=1) } else { hex }
  if body.length() != 6 {
    return None
  }
  let r = match hex_digit_c(body, 0) {
    Some(a) =>
      match hex_digit_c(body, 1) {
        Some(b) => a * 16 + b
        None => return None
      }
    None => return None
  }
  let g = match hex_digit_c(body, 2) {
    Some(a) =>
      match hex_digit_c(body, 3) {
        Some(b) => a * 16 + b
        None => return None
      }
    None => return None
  }
  let b = match hex_digit_c(body, 4) {
    Some(a) =>
      match hex_digit_c(body, 5) {
        Some(b2) => a * 16 + b2
        None => return None
      }
    None => return None
  }
  Some((r, g, b))
}

///|
/// fill 色暗化到约 27% 亮度（保留色相），返回 ANSI 前缀；无 rgb 则空串
fn faint_prefix(hex : String) -> String {
  match rgb_of(hex) {
    None => ""
    Some((r, g, b)) => "\u{1b}[38;2;\{r / 4};\{g / 4};\{b / 4}m"
  }
}

///|
fn pick_label(n : @core.Node) -> String {
  if n.text != "" {
    n.text
  } else {
    n.name
  }
}

///|
fn label_color_of(n : @core.Node) -> String {
  let f = n.style.fill
  let dark = f == "#FFFFFF" ||
    f == "none" ||
    f == "#EEF2FF" ||
    f == "#E0E7FF" ||
    f == "#CCFBF1" ||
    f == "#F2F3F5"
  if dark {
    ANSI_LABEL_DARK
  } else {
    ANSI_LABEL_LIGHT
  }
}

// ---------------------------------------------------------------------------
// 绘制
// ---------------------------------------------------------------------------

///|
/// 画一个世界矩形：box-drawing 边框 + 淡填色 + 标签（第 2 行起）
fn draw_world_rect(
  buf : ScreenBuf,
  camera : Camera,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  border : String,
  fill_hex : String,
  label : String,
  label_color : String,
) -> Unit {
  let t0 = to_screen_f(camera, x, y)
  let t1 = to_screen_f(camera, x + w, y + h)
  let col0 = t0.sx.to_int()
  let row0 = t0.sy.to_int()
  let col1 = t1.sx.to_int()
  let row1 = t1.sy.to_int()
  let sw = col1 - col0
  let sh = row1 - row0
  if sw <= 1 || sh <= 1 {
    screen_set(buf, col0, row0, '·', border)
    return
  }
  let fill : String = if has_pref(fill_hex, "#") {
    faint_prefix(fill_hex)
  } else {
    ""
  }
  // 内部填充（不覆盖边框线所在的四边）
  for row in (row0 + 1)..<(row1 - 1) {
    for col in (col0 + 1)..<(col1 - 1) {
      screen_set(buf, col, row, '·', fill)
    }
  }
  for col in col0..<col1 {
    screen_set(buf, col, row0, '─', border)
    screen_set(buf, col, row1 - 1, '─', border)
  }
  for row in row0..<row1 {
    screen_set(buf, col0, row, '│', border)
    screen_set(buf, col1 - 1, row, '│', border)
  }
  screen_set(buf, col0, row0, '┌', border)
  screen_set(buf, col1 - 1, row0, '┐', border)
  screen_set(buf, col0, row1 - 1, '└', border)
  screen_set(buf, col1 - 1, row1 - 1, '┘', border)
  // 标签画在容器内部第 2 行（放大时可见）
  let at = col0 + 2
  let label_row = row0 + 1
  for i in 0..<label.length() {
    match label.get_char(i) {
      Some(c) =>
        if at + i < col1 - 1 {
          match screen_char_at(buf, at + i, label_row) {
            Some(' ') => screen_set(buf, at + i, label_row, c, label_color)
            Some('·') => screen_set(buf, at + i, label_row, c, label_color)
            _ => ()
          }
        }
      None => ()
    }
  }
}

///|
/// 文档 → 栅格。高亮节点用亮色边框（拖拽/告警聚焦）。
pub fn draw_document(
  buf : ScreenBuf,
  camera : Camera,
  doc : @core.Document,
  highlight : String?,
) -> Unit {
  let layout = @core.solve(doc)
  draw_tree(buf, camera, doc, doc.root_id, layout, highlight)
}

///|
fn draw_tree(
  buf : ScreenBuf,
  camera : Camera,
  doc : @core.Document,
  id : String,
  layout : @core.SolvedLayout,
  highlight : String?,
) -> Unit {
  match doc.nodes.get(id) {
    None => ()
    Some(n) =>
      match layout.rect_of(id) {
        None => ()
        Some(r) => {
          let border : String = match highlight {
            Some(hid) => if hid == n.id { ANSI_ALERT } else { ANSI_BORDER }
            None => ANSI_BORDER
          }
          let fill_hex : String = if n.style.fill == "none" {
            "#FFFFFF"
          } else {
            n.style.fill
          }
          draw_world_rect(
            buf,
            camera,
            r.x,
            r.y,
            r.width,
            r.height,
            border,
            fill_hex,
            pick_label(n),
            label_color_of(n),
          )
          for cid in n.children.iter() {
            draw_tree(buf, camera, doc, cid, layout, highlight)
          }
        }
      }
  }
}

///|
/// 命中检测：屏幕列/行 → 世界坐标 → 含该点的最小面积节点 id
pub fn pick_at(
  doc : @core.Document,
  camera : Camera,
  col : Double,
  row : Double,
) -> String? {
  let (wx, wy) = to_world_f(camera, col, row)
  let layout = @core.solve(doc)
  let mut best : String? = None
  let mut best_area : Double = 0.0
  for id in doc.nodes.keys() {
    match layout.rect_of(id) {
      Some(r) =>
        if wx >= r.x && wy >= r.y && wx < r.x + r.width && wy < r.y + r.height {
          let area = r.width * r.height
          match best {
            None => {
              best = Some(id)
              best_area = area
            }
            Some(_) =>
              if area < best_area {
                best = Some(id)
                best_area = area
              }
          }
        }
      None => ()
    }
  }
  best
}
