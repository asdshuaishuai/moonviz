// ---------------------------------------------------------------------------
// 真终端渲染（Smart UX 渲染面之一）：把求解后的场景图光栅化为
// ANSI 真彩色（24-bit）字符网格——引擎自身输出，无 GUI 依赖。
// ---------------------------------------------------------------------------

// 网格单元：背景色（RGB24，-1 = 终端默认）、字符、前景色
priv struct TermCell {
  mut bg : Int
  mut fg : Int
  mut ch : Int
}

priv struct TermGrid {
  cols : Int
  rows : Int
  cells : Array[TermCell]
}

///|
fn term_grid(cols : Int, rows : Int) -> TermGrid {
  let cells : Array[TermCell] = []
  for _ in 0..<rows {
    for _ in 0..<cols {
      cells.push({ bg: -1, fg: -1, ch: 32 })
    }
  }
  { cols, rows, cells }
}

///|
fn term_get(grid : TermGrid, col : Int, row : Int) -> TermCell {
  grid.cells[row * grid.cols + col]
}

///|
/// "#RRGGBB" → 24-bit RGB（非 hex 返回 -1 = 不绘制）
fn term_hex_rgb(color : String) -> Int {
  let s = color
  if s.length() != 7 || s.get_char(0) != Some('#') {
    return -1
  }
  let mut v = 0
  for i in 1..<7 {
    match s.get_char(i) {
      Some(c) if c >= '0' && c <= '9' => v = v * 16 + (c.to_int() - 48)
      Some(c) if c >= 'a' && c <= 'f' => v = v * 16 + (c.to_int() - 87)
      Some(c) if c >= 'A' && c <= 'F' => v = v * 16 + (c.to_int() - 55)
      _ => return -1
    }
  }
  v
}

///|
/// 场景图递归绘制：先自身填充，再子节点（文档序 = 后画在上），最后自身文本
fn term_paint_node(
  grid : TermGrid,
  doc : Document,
  id : String,
  layout : SolvedLayout,
  px_w : Double,
  px_h : Double,
) -> Unit {
  match doc.nodes.get(id) {
    None => ()
    Some(n) =>
      match layout.rect_of(id) {
        None => ()
        Some(r) => {
          // 像素 → 网格
          // clamp 上界为 cols/rows（不含）——节点在画板底缘之下时整块裁剪，
          // 修评审发现的越界 SIGABRT（cy0==rows 时 term_get 越界）
          let cx0 = term_clamp((r.x / px_w * grid.cols.to_double()).to_int(), 0, grid.cols)
          let cy0 = term_clamp((r.y / px_h * grid.rows.to_double()).to_int(), 0, grid.rows)
          let cx1 = term_clamp(((r.x + r.width) / px_w * grid.cols.to_double()).to_int(), cx0, grid.cols)
          let cy1 = term_clamp(((r.y + r.height) / px_h * grid.rows.to_double()).to_int(), cy0, grid.rows)
          if cx0 >= grid.cols || cy0 >= grid.rows {
            return
          }
          // 填充（纯色 hex 才绘制；none/渐变跳过）
          let bg = term_hex_rgb(n.style.fill)
          if bg >= 0 {
            for row in cy0..<cy1 {
              for col in cx0..<cx1 {
                let cell = term_get(grid, col, row)
                cell.bg = bg
              }
            }
          }
          // 子节点
          for cid in n.children.iter() {
            term_paint_node(grid, doc, cid, layout, px_w, px_h)
          }
          // 文本（垂直居中于矩形，水平起点 = 左缘 + 2 格，裁剪于矩形内）
          if n.text != "" && cx1 > cx0 + 1 {
            let fg = term_hex_rgb(n.style.text_color)
            if fg >= 0 {
              let font_px = n.style.font_size
              let row_px = px_h / grid.rows.to_double()
              let center_px = r.y + r.height / 2.0
              let ty = term_clamp(
                ((center_px + font_px * 0.35) / row_px).to_int(),
                cy0,
                if cy1 > cy0 { cy1 - 1 } else { cy0 },
              )
              if ty >= grid.rows {
                return
              }
              let tx0 = term_clamp(cx0 + 2, cx0, cx1)
              let mut col = tx0
              for ch in n.text.iter() {
                if col >= cx1 {
                  break
                }
                let cell = term_get(grid, col, ty)
                cell.ch = ch.to_int()
                cell.fg = fg
                col = col + 1
              }
            }
          }
        }
      }
  }
}

///|
fn term_clamp(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
/// SGR 真彩色片段
fn term_sgr_bg(rgb : Int) -> String {
  "\u{1b}[48;2;\{((rgb >> 16) & 255)};\{((rgb >> 8) & 255)};\{(rgb & 255)}m"
}

///|
fn term_sgr_fg(rgb : Int) -> String {
  "\u{1b}[38;2;\{((rgb >> 16) & 255)};\{((rgb >> 8) & 255)};\{(rgb & 255)}m"
}

///|
/// 网格 → ANSI 字符串（按 run 合并以最小化转义序列；行末 reset + 换行）
fn term_emit(grid : TermGrid) -> String {
  let sb = StringBuilder::new()
  for row in 0..<grid.rows {
    let mut last_bg = -2
    let mut last_fg = -2
    for col in 0..<grid.cols {
      let cell = term_get(grid, col, row)
      if cell.bg != last_bg {
        if cell.bg < 0 {
          sb.write_string("\u{1b}[0m")
        } else {
          sb.write_string(term_sgr_bg(cell.bg))
        }
        last_bg = cell.bg
        last_fg = -2
      }
      if cell.ch != 32 {
        if cell.fg != last_fg {
          if cell.fg < 0 {
            sb.write_string("\u{1b}[39m")
          } else {
            sb.write_string(term_sgr_fg(cell.fg))
          }
          last_fg = cell.fg
        }
        sb.write_char(Int::to_char(cell.ch).unwrap_or(' '))
      } else {
        sb.write_char(' ')
      }
    }
    sb.write_string("\u{1b}[0m\n")
  }
  sb.to_string()
}

///|
/// Smart UX 终端渲染入口：画板 → ANSI 真彩色字符串。
/// cols 为列数；行数按画板纵横比与 2:1 字格推算（上限 80 行）。
pub fn render_term_svg(
  doc : Document,
  surface~ : String,
  cols? : Int = 100,
) -> String {
  let w = cols
  let layout = solve(doc)
  let root_rect : Rect = match layout.rect_of(doc.root_id) {
    Some(r) => r
    None => Rect::new(0.0, 0.0, 390.0, 844.0)
  }
  let px_w = if root_rect.width > 0 { root_rect.width } else { 390.0 }
  let px_h = if root_rect.height > 0 { root_rect.height } else { 844.0 }
  let mut rows = (px_h / px_w * w.to_double() / 2.0).to_int()
  if rows < 1 {
    rows = 1
  }
  if rows > 80 {
    rows = 80
  }
  let grid = term_grid(w, rows)
  // 表面底色铺满（主题一致）
  let surface_rgb = term_hex_rgb(surface)
  if surface_rgb >= 0 {
    for row in 0..<rows {
      for col in 0..<w {
        let cell = term_get(grid, col, row)
        cell.bg = surface_rgb
      }
    }
  }
  // 忽略根框（root 的描边框不参与终端绘制）——从根的子节点开始画
  match doc.nodes.get(doc.root_id) {
    Some(root) =>
      for cid in root.children.iter() {
        term_paint_node(grid, doc, cid, layout, px_w, px_h)
      }
    None => ()
  }
  term_emit(grid)
}
