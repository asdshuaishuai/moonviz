///|
/// “不崩”谓词（docs/04）：对 (文档, 求解结果) 的纯函数检查。
///
/// 分级原则：结构硬，视觉软/硬。
/// - 结构性谓词（TreeValid / SizeValid）：文档坏到无法继续，两条路线都硬阻断。
/// - 视觉性谓词（ContainedInParent / NoSiblingOverlap / ConstraintSolvable）：
///   人类路线软提示（保留决定权），Agent 路线硬门槛（拒绝合并）。
/// 策略落地在 policy.mbt 的 decide()。
pub(all) enum Predicate {
  TreeValid // 结构：单根可达、引用完整、无重复/成环
  SizeValid // 结构：求解出的宽高非负、有限
  ContainedInParent // 视觉：栈布局容器的子节点不超出内容盒
  NoSiblingOverlap // 视觉：栈布局容器的兄弟节点两两不重叠
  ConstraintSolvable // 视觉：约束系统有解（求解失败 = 无解）
}

///|
pub fn Predicate::name(self : Predicate) -> String {
  match self {
    TreeValid => "tree_valid"
    SizeValid => "size_valid"
    ContainedInParent => "contained_in_parent"
    NoSiblingOverlap => "no_sibling_overlap"
    ConstraintSolvable => "constraint_solvable"
  }
}

///|
pub fn Predicate::is_structural(self : Predicate) -> Bool {
  match self {
    TreeValid => true
    SizeValid => true
    _ => false
  }
}

///|
pub(all) struct Violation {
  predicate : Predicate
  node_id : String
  detail : String
}

///|
/// 全量校验：结构 + 尺寸 + 视觉 + 可解性
pub fn validate(doc : Document) -> Array[Violation] {
  let out : Array[Violation] = Array::new()
  append_violations(out, check_tree_valid(doc))
  let layout = solve(doc)
  append_violations(out, check_size_valid(layout))
  append_violations(out, check_visual_frames(doc, layout))
  append_violations(out, check_solvable(doc, layout))
  out
}

///|
fn append_violations(target : Array[Violation], src : Array[Violation]) -> Unit {
  for v in src.iter() {
    target.push(v)
  }
}

///|
/// P0：从根 DFS，检查引用完整、无重复引用（成环/多父）、无不可达节点
fn check_tree_valid(doc : Document) -> Array[Violation] {
  let out : Array[Violation] = Array::new()
  if !doc.has(doc.root_id) {
    out.push({
      predicate: TreeValid,
      node_id: doc.root_id,
      detail: "根节点不存在",
    })
    return out
  }
  let visited : Map[String, Bool] = Map::new()
  visited.set(doc.root_id, true)
  let stack : Array[String] = [doc.root_id]
  while stack.length() > 0 {
    match stack.pop() {
      None => ()
      Some(cur) =>
        match doc.nodes.get(cur) {
          None =>
            out.push({
              predicate: TreeValid,
              node_id: cur,
              detail: "被引用的节点不存在",
            })
          Some(n) =>
            for cid in n.children.iter() {
              if visited.contains(cid) {
                out.push({
                  predicate: TreeValid,
                  node_id: cid,
                  detail: "节点被重复引用（成环或多个父亲）",
                })
              } else {
                visited.set(cid, true)
                stack.push(cid)
              }
            }
        }
    }
  }
  for id in doc.nodes.keys() {
    if !visited.contains(id) {
      out.push({
        predicate: TreeValid,
        node_id: id,
        detail: "节点不可从根到达（孤儿或游离子树）",
      })
    }
  }
  out
}

///|
/// P1：所有求解矩形非负、有限（NaN/Inf 天然不通过比较）
fn check_size_valid(layout : SolvedLayout) -> Array[Violation] {
  let out : Array[Violation] = Array::new()
  for id in layout.rects.keys() {
    match layout.rects.get(id) {
      Some(r) =>
        if !size_is_valid(r.width, r.height) {
          out.push({
            predicate: SizeValid,
            node_id: id,
            detail: "尺寸无效：width=\{r.width}, height=\{r.height}",
          })
        }
      None => ()
    }
  }
  out
}

///|
/// P2 + P3：对所有 Frame 检查“包含 + 兄弟重叠”（自由层的出血/裁剪
/// 与重叠同属设计债——人类软提示，Agent 硬门槛）。
fn check_visual_frames(
  doc : Document,
  layout : SolvedLayout,
) -> Array[Violation] {
  let out : Array[Violation] = Array::new()
  let visited : Map[String, Bool] = Map::new()
  visited.set(doc.root_id, true)
  let stack : Array[String] = [doc.root_id]
  while stack.length() > 0 {
    match stack.pop() {
      None => ()
      Some(cur) =>
        match doc.nodes.get(cur) {
          None => ()
          Some(n) => {
            match n.kind {
              Frame =>
                match layout.rects.get(cur) {
                  Some(frame_rect) => {
                    // 包含 + 重叠对所有 Frame 生效（栈内容盒含 padding，
                    // 绝对层即父矩形）；出血类设计记为视觉债，M2 提供逐节点豁免标记
                    let content : Rect = match n.layout {
                      Some(l) =>
                        frame_rect.inset(
                          l.padding.top,
                          l.padding.right,
                          l.padding.bottom,
                          l.padding.left,
                        )
                      None => frame_rect
                    }
                    let kids = n.children
                    for i in 0..<kids.length() {
                      match layout.rects.get(kids[i]) {
                        None => ()
                        Some(ri) =>
                          if !content.contains_rect(ri) {
                            out.push({
                              predicate: ContainedInParent,
                              node_id: kids[i],
                              detail: "子节点超出父容器 \{cur} 的内容盒",
                            })
                          }
                      }
                    }
                    push_overlap_violations(out, kids, layout, cur)
                  }
                  None => ()
                }
              _ => ()
            }
            for cid in n.children.iter() {
              if !visited.contains(cid) {
                visited.set(cid, true)
                stack.push(cid)
              }
            }
          }
        }
    }
  }
  out
}

///|
/// 兄弟两两相交检查（O(n^2)，v1 节点规模下足够）
fn push_overlap_violations(
  out : Array[Violation],
  kids : Array[String],
  layout : SolvedLayout,
  parent_id : String,
) -> Unit {
  for i in 0..<kids.length() {
    match layout.rects.get(kids[i]) {
      None => ()
      Some(ri) => {
        let mut j = i + 1
        while j < kids.length() {
          match layout.rects.get(kids[j]) {
            Some(rj) =>
              if ri.intersects(rj) {
                out.push({
                  predicate: NoSiblingOverlap,
                  node_id: kids[i],
                  detail: "与兄弟 \{kids[j]} 在 \{parent_id} 内重叠",
                })
              }
            None => ()
          }
          j = j + 1
        }
      }
    }
  }
}

///|
/// P4：求解失败 = 约束系统无解
fn check_solvable(doc : Document, layout : SolvedLayout) -> Array[Violation] {
  let out : Array[Violation] = Array::new()
  for f in layout.failures.iter() {
    match f {
      MissingRoot =>
        out.push({
          predicate: ConstraintSolvable,
          node_id: doc.root_id,
          detail: "根节点缺失，无法求解",
        })
      MissingNode(id) =>
        out.push({
          predicate: ConstraintSolvable,
          node_id: id,
          detail: "约束引用了不存在的节点",
        })
      NegativeResidual(id, r) =>
        out.push({
          predicate: ConstraintSolvable,
          node_id: id,
          detail: "容器内容超出可用空间，缺口 \{r}，无法分配 Fill 子项",
        })
      UnsupportedSpec(id) =>
        out.push({
          predicate: ConstraintSolvable,
          node_id: id,
          detail: "尺寸规格在当前求解器下无定义",
        })
    }
  }
  out
}
