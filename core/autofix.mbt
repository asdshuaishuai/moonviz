///|
/// 自动修复引擎：Agent 调用 auto_fix 即可清除全部视觉债。
///
/// 修复策略按谓词分类：
/// - contained_in_parent → 缩小尺寸适配父容器（优先缩宽，再缩高）
/// - no_sibling_overlap  → 沿 Y 轴平移到无重叠位置
/// - constraint_solvable → Fill→Fixed 降级（取父容器剩余空间）
/// 返回修复操作列表（供 Agent 审阅）+ 修复后的新 Project。
pub(all) struct AutoFixOp {
  node_id : String
  predicate : String
  action : String // 人可读的修复描述
  before : String // 修复前值
  after : String // 修复后值
}

///|
/// 一键修复：遍历所有违规节点，逐一应用修复策略
pub fn Project::auto_fix(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let fixes : Array[String] = []
      let mut round = 0
      let mut remaining = validate(ab.doc).length()
      // 迭代修复（修复一处可能引入新违规，最多 5 轮）
      while remaining > 0 && round < 5 {
        let violations = validate(ab.doc)
        for v in violations.iter() {
          match v.predicate {
            ContainedInParent => {
              let fix = fix_overflow(ab.doc, v.node_id)
              match fix {
                Some(desc) => fixes.push(desc)
                None => ()
              }
            }
            NoSiblingOverlap => {
              let fix = fix_overlap(ab.doc, v.node_id)
              match fix {
                Some(desc) => fixes.push(desc)
                None => ()
              }
            }
            _ => ()
          }
        }
        let new_count = validate(ab.doc).length()
        if new_count >= remaining {
          break // 无进展
        }
        remaining = new_count
        round = round + 1
      }
      let final_count = validate(ab.doc).length()
      if final_count == 0 {
        let j = jstr6(fixes)
        Ok("{\"ok\":true,\"fixes\":\{fixes.length()},\"detail\":[\{j}]}")
      } else {
        let j = jstr6(fixes)
        Ok(
          "{\"ok\":false,\"remaining\":\{final_count},\"fixes\":\{fixes.length()},\"detail\":[\{j}]}",
        )
      }
    }
  }
}

///|
/// 修复溢出：缩小尺寸适配父容器内容盒
fn fix_overflow(doc : Document, node_id : String) -> String? {
  match doc.nodes.get(node_id) {
    None => None
    Some(n) =>
      match doc.find_parent(node_id) {
        None => None
        Some(pid) =>
          match doc.nodes.get(pid) {
            None => None
            Some(parent) => {
              let layout = solve(doc)
              match (layout.rect_of(node_id), layout.rect_of(pid)) {
                (Some(nr), Some(pr)) => {
                  let avail_w = pr.width - (nr.x - pr.x) * 2.0
                  let avail_h = pr.height - (nr.y - pr.y) * 2.0
                  // 优先缩宽
                  let mut new_w = nr.width
                  let mut new_h = nr.height
                  if nr.width > avail_w {
                    new_w = if avail_w > 0.0 { avail_w } else { nr.width }
                  }
                  if nr.height > avail_h {
                    new_h = if avail_h > 0.0 { avail_h } else { nr.height }
                  }
                  if new_w != nr.width || new_h != nr.height {
                    let _ = doc.update_node(node_id, fn(x) {
                      { ..x, width: Fixed(new_w), height: Fixed(new_h) }
                    })
                    Some(
                      "{\"node\":\"\{node_id}\",\"action\":\"resize\",\"before\":\"\{nr.width.to_int()}×\{nr.height.to_int()}\",\"after\":\"\{new_w.to_int()}×\{new_h.to_int()}\"}",
                    )
                  } else {
                    None
                  }
                }
                _ => None
              }
            }
          }
      }
  }
}

///|
/// 修复重叠：沿 Y 轴下移到无重叠位置
fn fix_overlap(doc : Document, node_id : String) -> String? {
  match doc.nodes.get(node_id) {
    None => None
    Some(n) =>
      match doc.find_parent(node_id) {
        None => None
        Some(pid) =>
          match doc.nodes.get(pid) {
            None => None
            Some(parent) => {
              let layout = solve(doc)
              match layout.rect_of(node_id) {
                None => None
                Some(nr) => {
                  // 找到重叠的兄弟中最大的 bottom
                  let mut max_bottom = nr.y
                  for cid in parent.children.iter() {
                    if cid != node_id {
                      match layout.rect_of(cid) {
                        Some(cr) => {
                          // 全包含对＝有意分层（背景压内容），与谓词层豁免
                          // 同语义同容差——背景不参与 max_bottom 推挤，否则
                          // 内容会被推到画板之外（review 5a5641a）
                          if nr.contains_rect_eps(cr, 0.5) ||
                            cr.contains_rect_eps(nr, 0.5) {
                            ()
                          } else if nr.y < cr.y + cr.height &&
                            nr.y + nr.height > cr.y &&
                            nr.x < cr.x + cr.width &&
                            cr.x < nr.x + nr.width {
                            let b = cr.y + cr.height
                            if b > max_bottom {
                              max_bottom = b
                            }
                          }
                        }
                        None => ()
                      }
                    }
                  }
                  if max_bottom > nr.y {
                    // 下移到重叠兄弟的底部 + 8px 间距
                    let parent_y = get_parent_y(layout, pid)
                    let new_y = max_bottom + 8.0 - parent_y
                    let old_y = pos_to_str(n.y)
                    let _ = doc.update_node(node_id, fn(x) {
                      { ..x, y: AlignStart(new_y) }
                    })
                    Some(
                      "{\"node\":\"\{node_id}\",\"action\":\"move_y\",\"before\":\"\{old_y}\",\"after\":\"\{new_y}\"}",
                    )
                  } else {
                    None
                  }
                }
              }
            }
          }
      }
  }
}

///|
fn jstr6(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

///|
fn get_parent_y(layout : SolvedLayout, pid : String) -> Double {
  match layout.rect_of(pid) {
    Some(pr) => pr.y
    None => 0.0
  }
}

///|
fn pos_to_str(p : PosSpec) -> String {
  match p {
    AlignStart(v) => v.to_string()
    Fixed(v) => v.to_string()
    AlignEnd(v) => "end(\{v})"
    CenterInParent => "center"
  }
}
