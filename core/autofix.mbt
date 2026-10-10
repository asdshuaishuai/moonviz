///|
/// 自动修复引擎：Agent 调用 auto_fix 即可清除全部视觉债。
///
/// 修复策略按谓词分类：
/// - contained_in_parent → 缩小尺寸适配父容器（优先缩宽，再缩高）
/// - no_sibling_overlap  → 沿 Y 轴平移到无重叠位置
/// - constraint_solvable → Fill→Fixed 降级（取父容器剩余空间）
/// 另有组件规范预修（norms.mbt：按钮放大到文案+留白 / 圆角归档 8 / 全宽条直角），
/// 在谓词迭代之前执行——规范修复可能引入新违规，交给后续谓词循环一并清理。
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
      // 组件规范先修（按钮卡文案放大/圆角归档/全宽条直角/列表行间分割线）：
      // 放大可能引入新的重叠/溢出，所以必须在视觉债迭代**之前**执行，让下面
      // 的谓词循环把新引入的违规一并清掉。
      let norm_layout = solve(ab.doc)
      for f in norm_fix_pass(ab.doc, norm_layout).iter() {
        fixes.push(f)
      }
      for f in self.norm_list_divider_fix(artboard=artboard).iter() {
        fixes.push(f)
      }
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
                      { ..x, width: Fixed(new_w), height: Fixed(new_h), }
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
                        Some(cr) =>
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
                      { ..x, y: AlignStart(new_y), }
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

///|
/// 列表分割线修复：给齐缝 list_item 连排（norms_list_runs）的每一行——
/// 除最后一行——行底插入 1px divider 子节点。走 place_component 真实
/// 实例化路径（divider 变体的 outline_variant 色随主题解析）；子节点挂在
/// 行内，不参与兄弟重叠检查（v1 只查 Frame 子节点），包含检查也只对
/// Frame 生效——零门风险，不引入视觉债。行内已有 divider 则跳过（幂等）。
fn Project::norm_list_divider_fix(
  self : Project,
  artboard~ : String,
) -> Array[String] {
  let fixes : Array[String] = []
  match self.artboards.get(artboard) {
    None => ()
    Some(ab) => {
      let layout = solve(ab.doc)
      for run in norms_list_runs(ab.doc, layout).iter() {
        let n = run.row_ids.length()
        for idx in 0..<(n - 1) {
          let row_id = run.row_ids[idx]
          match (ab.doc.nodes.get(row_id), layout.rect_of(row_id)) {
            (Some(row), Some(rr)) => {
              let mut has = false
              for cid in row.children.iter() {
                match ab.doc.nodes.get(cid) {
                  Some(c) => if c.component == "divider" { has = true }
                  None => ()
                }
              }
              if has {
                continue
              }
              let sep_id = row_id + "_sep"
              match self.place_component(
                artboard=artboard,
                component_id="divider",
                instance_id=sep_id,
                parent_id=row_id,
                x=16.0,
                y=rr.height - 1.0,
                w=rr.width - 32.0,
                h=1.0,
              ) {
                Ok(_) =>
                  fixes.push(
                    "{\"node\":\"\{json_escape(row_id)}\",\"action\":\"list_divider\",\"why\":\"列表行间分割线\",\"after\":\"行底 1px divider（\{json_escape(sep_id)}）\"}",
                  )
                Err(_) => ()
              }
            }
            _ => ()
          }
        }
      }
    }
  }
  fixes
}
