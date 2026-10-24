/// 智能对齐引擎：让 Agent 的"随手放"变成"精确设计"。
///
/// 设计师拖拽时会看到辅助线、吸附、等间距提示。
/// Agent 的等价体验是：放置后调用 `smart_align` 获得专业排版。
///
/// - auto_arrange：所有子元素垂直等间距排列
/// - align_row：水平一行等间距
/// - snap_to_grid：所有位置吸附到 N px 网格
/// - center_in_parent：居中对齐
/// - suggest_alignment：检测近似对齐并建议吸附

// ---------------------------------------------------------------------------
// 自动排列
// ---------------------------------------------------------------------------

///|
/// 所有子元素垂直等间距排列（容器内）
pub fn Project::auto_arrange(
  self : Project,
  artboard~ : String,
  parent_id? : String = "root",
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) =>
      match ab.doc.nodes.get(parent_id) {
        None => Err("unknown_parent")
        Some(parent) => {
          let n_children = parent.children.length()
          if n_children < 2 {
            return Ok(
              "{\"ok\":true,\"message\":\"少于2个子元素，无需排列\"}",
            )
          }
          // 计算总高度和可用空间
          let layout = solve(ab.doc)
          let parent_rect = match layout.rect_of(parent_id) {
            Some(r) => r
            None => return Err("layout_error")
          }
          let padding = 16.0
          let gap = 12.0
          let avail_h = parent_rect.height -
            padding * 2.0 -
            gap * (n_children - 1).to_double()
          let item_h = avail_h / n_children.to_double()
          let item_h = if item_h > 80.0 {
            80.0
          } else if item_h < 36.0 {
            36.0
          } else {
            item_h
          }
          // 重新排列
          let mut y = parent_rect.y + padding
          let fixed : Array[String] = []
          for cid in parent.children.iter() {
            match ab.doc.nodes.get(cid) {
              Some(child) => {
                let cur_h = match layout.rect_of(cid) {
                  Some(r) => r.height
                  None => item_h
                }
                let h = if cur_h > 0.0 { cur_h } else { item_h }
                let _ = ab.doc.update_node(cid, fn(c) {
                  {
                    ..c,
                    x: AlignStart(padding),
                    y: AlignStart(y - parent_rect.y),
                    width: Fill,
                    height: Fixed(h),
                  }
                })
                fixed.push(
                  "{\"id\":\"\{cid}\",\"y\":\{y.to_int()},\"h\":\{h.to_int()}}",
                )
                y = y + h + gap
              }
              None => ()
            }
          }
          let j = jstr10(fixed)
          Ok("{\"ok\":true,\"arranged\":\{n_children},\"detail\":[\{j}]}")
        }
      }
  }
}

// ---------------------------------------------------------------------------
// 网格吸附
// ---------------------------------------------------------------------------

///|
/// 所有节点位置吸附到 N px 网格
pub fn Project::snap_to_grid(
  self : Project,
  artboard~ : String,
  grid? : Double = 8.0,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let snapped : Array[String] = []
      // 先解一次布局取全部绝对矩形做吸附快照，再自根向下统一写回：
      // 写回值是「相对父容器新原点」的偏移（父也在移动），与 Map 迭序无关。
      // 直接把绝对吸附坐标当相对偏移写回，会让嵌套节点整体偏移一个父原点。
      let layout = solve(ab.doc)
      let targets : Map[String, (Double, Double)] = Map::new()
      for id in ab.doc.nodes.keys() {
        if id != "root" {
          match layout.rect_of(id) {
            Some(r) => {
              let new_x = snap_val(r.x, grid)
              let new_y = snap_val(r.y, grid)
              if new_x != r.x || new_y != r.y {
                targets.set(id, (new_x, new_y))
              }
            }
            None => ()
          }
        }
      }
      // DFS（父先于子）：子节点用父的新绝对原点换算 AlignStart 偏移
      let stack : Array[(String, Double, Double)] = []
      match layout.rect_of(ab.doc.root_id) {
        Some(rr) => stack.push((ab.doc.root_id, rr.x, rr.y))
        None => ()
      }
      while stack.length() > 0 {
        match stack.pop() {
          None => ()
          Some((id, px, py)) => {
            let (nx, ny) = match targets.get(id) {
              Some((tx, ty)) => {
                let (ox, oy) = match layout.rect_of(id) {
                  Some(r) => (r.x, r.y)
                  None => (tx, ty)
                }
                let _ = ab.doc.update_node(id, fn(c) {
                  {
                    ..c,
                    x: AlignStart(tx - px),
                    y: AlignStart(ty - py),
                  }
                })
                snapped.push(
                  "{\"id\":\"\{id}\",\"from\":\"\{ox.to_int()},\{oy.to_int()}\",\"to\":\"\{tx.to_int()},\{ty.to_int()}\"}",
                )
                (tx, ty)
              }
              None =>
                match layout.rect_of(id) {
                  Some(r) => (r.x, r.y)
                  None => (px, py)
                }
            }
            match ab.doc.nodes.get(id) {
              Some(node) =>
                for cid in node.children.iter() {
                  stack.push((cid, nx, ny))
                }
              None => ()
            }
          }
        }
      }
      let j = jstr10(snapped)
      Ok(
        "{\"ok\":true,\"snapped\":\{snapped.length()},\"grid\":\{grid},\"detail\":[\{j}]}",
      )
    }
  }
}

///|
fn snap_val(v : Double, grid : Double) -> Double {
  if grid <= 0.0 {
    return v
  }
  (v / grid).to_int().to_double() * grid
}

// ---------------------------------------------------------------------------
// 居中对齐
// ---------------------------------------------------------------------------

///|
/// 将节点在父容器内水平居中
pub fn Project::center_in_parent(
  self : Project,
  artboard~ : String,
  node_id~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) =>
      match ab.doc.find_parent(node_id) {
        None => Err("no_parent")
        Some(pid) => {
          let layout = solve(ab.doc)
          match (layout.rect_of(node_id), layout.rect_of(pid)) {
            (Some(nr), Some(pr)) => {
              let centered_x = pr.x + (pr.width - nr.width) / 2.0
              let _ = ab.doc.update_node(node_id, fn(c) {
                { ..c, x: AlignStart(centered_x - pr.x), }
              })
              Ok(
                "{\"ok\":true,\"id\":\"\{node_id}\",\"x\":\{centered_x.to_int()}}",
              )
            }
            _ => Err("layout_error")
          }
        }
      }
  }
}

// ---------------------------------------------------------------------------
// 对齐建议（检测近似对齐）
// ---------------------------------------------------------------------------

///|
pub(all) struct AlignmentHint {
  node_a : String
  node_b : String
  axis : String // "x" | "y" | "right" | "center_x"
  delta : Double // 当前偏差
  suggestion : String // 人可读建议
}

///|
/// 检测近似对齐并给出建议
pub fn Project::suggest_alignment(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let layout = solve(ab.doc)
      let ids : Array[String] = []
      for id in ab.doc.nodes.keys() {
        if id != "root" {
          ids.push(id)
        }
      }
      let hints : Array[String] = []
      let threshold = 4.0 // 小于 4px 视为"接近对齐"
      for i in 0..<ids.length() {
        for j in (i + 1)..<ids.length() {
          match (layout.rect_of(ids[i]), layout.rect_of(ids[j])) {
            (Some(ra), Some(rb)) => {
              // 左边缘接近
              let dx = ra.x - rb.x
              if dx != 0.0 && dx.abs() < threshold {
                let s = "左边缘偏差 \{dx.to_string()}px：\{ids[i]} 和 \{ids[j]} 左对齐"
                hints.push(
                  "{\"type\":\"left\",\"a\":\"\{ids[i]}\",\"b\":\"\{ids[j]}\",\"delta\":\{dx},\"suggestion\":\"\{s}\"}",
                )
              }
              // 顶边缘接近
              let dy = ra.y - rb.y
              if dy != 0.0 && dy.abs() < threshold {
                let s2 = "顶边缘偏差 \{dy.to_string()}px：\{ids[i]} 和 \{ids[j]} 顶对齐"
                hints.push(
                  "{\"type\":\"top\",\"a\":\"\{ids[i]}\",\"b\":\"\{ids[j]}\",\"delta\":\{dy},\"suggestion\":\"\{s2}\"}",
                )
              }
              // 水平中心接近
              let ca = ra.x + ra.width / 2.0
              let cb = rb.x + rb.width / 2.0
              let dc = ca - cb
              if dc != 0.0 && dc.abs() < threshold {
                let s3 = "水平中心偏差 \{dc.to_string()}px：\{ids[i]} 和 \{ids[j]} 居中对齐"
                hints.push(
                  "{\"type\":\"center_x\",\"a\":\"\{ids[i]}\",\"b\":\"\{ids[j]}\",\"delta\":\{dc},\"suggestion\":\"\{s3}\"}",
                )
              }
            }
            _ => ()
          }
        }
      }
      let hj = jstr10(hints)
      Ok("{\"ok\":true,\"hints\":\{hints.length()},\"detail\":[\{hj}]}")
    }
  }
}

///|
fn jstr10(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
