///|
/// 布局求解：两遍法（先解尺寸、后解位置），见 docs/03。
///
/// 失败 ≠ 崩溃：求解器永远产出有限的矩形；解不开的约束记入 failures，
/// 由谓词层（predicates.mbt）定级为“约束系统无解”。这个接口稳定，
/// 未来可把实现换成 Cassowary / SMT 求解器而不影响验证协议。
pub(all) enum SolveFailure {
  MissingRoot
  MissingNode(String)
  NegativeResidual(String, Double) // 容器 id，剩余主轴空间（负值）
  UnsupportedSpec(String) // v1 求解器不支持的规格组合
}

///|
pub fn SolveFailure::describe(self : SolveFailure) -> String {
  match self {
    MissingRoot => "根节点缺失，无法求解"
    MissingNode(id) => "布局引用了不存在的节点：\{id}"
    NegativeResidual(id, r) =>
      "容器 \{id} 可用主轴空间不足，缺口 \{r}"
    UnsupportedSpec(id) =>
      "节点 \{id} 的尺寸规格在 v1 求解器下无定义（Hug 仅 Text 支持，根节点须 Fixed）"
  }
}

///|
pub(all) struct SolvedLayout {
  rects : Map[String, Rect]
  failures : Array[SolveFailure]
}

///|
pub fn SolvedLayout::rect_of(self : SolvedLayout, id : String) -> Rect? {
  self.rects.get(id)
}

///|
/// 求解入口：输入文档，输出每个节点的画布绝对矩形 + 求解失败列表
pub fn solve(doc : Document) -> SolvedLayout {
  let rects : Map[String, Rect] = Map::new()
  let failures : Array[SolveFailure] = Array::new()
  match doc.nodes.get(doc.root_id) {
    None => failures.push(MissingRoot)
    Some(root) => {
      let w = match root.width {
        Fixed(v) => v
        _ => 0.0
      }
      let h = match root.height {
        Fixed(v) => v
        _ => 0.0
      }
      let root_ok = match (root.width, root.height) {
        (Fixed(_), Fixed(_)) => true
        _ => false
      }
      if !root_ok {
        failures.push(UnsupportedSpec(root.id))
      }
      solve_node(doc, root, Rect::new(0.0, 0.0, w, h), rects, failures)
    }
  }
  { rects, failures }
}

///|
fn solve_node(
  doc : Document,
  node : Node,
  frame : Rect,
  rects : Map[String, Rect],
  failures : Array[SolveFailure],
) -> Unit {
  rects.set(node.id, frame)
  // 布局仅对 Frame 生效；其余种类一律按绝对定位处理其子节点
  let layout_opt : StackLayout? = match node.kind {
    Frame => node.layout
    _ => None
  }
  match layout_opt {
    Some(l) => solve_stack(doc, node, l, frame, rects, failures)
    None => solve_absolute(doc, node, frame, rects, failures)
  }
}

///|
/// 内在尺寸：Hug 只支持 Text（v1 限制），其余记为求解失败并给 0
fn intrinsic_size(node : Node, failures : Array[SolveFailure]) -> Size {
  match node.kind {
    Text =>
      text_intrinsic(
        node.text,
        node.style.font_size,
        line_height=node.style.line_height,
      )
    _ => {
      failures.push(UnsupportedSpec(node.id))
      { width: 0.0, height: 0.0 }
    }
  }
}

///|
/// 位置规格解析：在给定盒（栈布局的内容盒，或绝对定位的父矩形）内求坐标。
/// 栈内主轴位置由游标决定，不经过本函数。
fn resolve_pos(spec : PosSpec, area : Rect, size : Double) -> Double {
  match spec {
    Fixed(v) => area.x + v
    AlignStart(off) => area.x + off
    AlignEnd(off) => area.right() - off - size
    CenterInParent => area.x + (area.width - size) / 2.0
  }
}

///|
/// 位置规格解析（Y 轴）：在给定盒内求纵坐标
fn resolve_pos_y(spec : PosSpec, area : Rect, size : Double) -> Double {
  match spec {
    Fixed(v) => area.y + v
    AlignStart(off) => area.y + off
    AlignEnd(off) => area.bottom() - off - size
    CenterInParent => area.y + (area.height - size) / 2.0
  }
}

///|
/// 栈布局求解：先汇总主轴尺寸并分配 Fill，再按游标定位并递归
fn solve_stack(
  doc : Document,
  node : Node,
  l : StackLayout,
  frame : Rect,
  rects : Map[String, Rect],
  failures : Array[SolveFailure],
) -> Unit {
  let content = frame.inset(
    l.padding.top,
    l.padding.right,
    l.padding.bottom,
    l.padding.left,
  )
  let n = node.children.length()
  let main_sizes : Array[Double] = Array::new()
  let cross_sizes : Array[Double] = Array::new()
  let fill_idx : Array[Int] = Array::new()
  let mut fixed_total = 0.0
  for cid in node.children.iter() {
    match doc.nodes.get(cid) {
      None => {
        failures.push(MissingNode(cid))
        main_sizes.push(0.0)
        cross_sizes.push(0.0)
      }
      Some(child) => {
        let cross : Double = match l.dir {
          Vertical =>
            match child.width {
              Fixed(v) => v
              Fill => content.width
              Hug => intrinsic_size(child, failures).width
            }
          Horizontal =>
            match child.height {
              Fixed(v) => v
              Fill => content.height
              Hug => intrinsic_size(child, failures).height
            }
        }
        let main : Double = match l.dir {
          Vertical =>
            match child.height {
              Fixed(v) => {
                fixed_total = fixed_total + v
                v
              }
              Fill => {
                fill_idx.push(main_sizes.length())
                0.0
              }
              Hug => {
                let s = intrinsic_size(child, failures)
                fixed_total = fixed_total + s.height
                s.height
              }
            }
          Horizontal =>
            match child.width {
              Fixed(v) => {
                fixed_total = fixed_total + v
                v
              }
              Fill => {
                fill_idx.push(main_sizes.length())
                0.0
              }
              Hug => {
                let s = intrinsic_size(child, failures)
                fixed_total = fixed_total + s.width
                s.width
              }
            }
        }
        cross_sizes.push(cross)
        main_sizes.push(main)
      }
    }
  }
  let gap_total = if n > 0 { l.gap * (n - 1).to_double() } else { 0.0 }
  let content_main : Double = match l.dir {
    Vertical => content.height
    Horizontal => content.width
  }
  let residual = content_main - fixed_total - gap_total
  let fill_count = fill_idx.length()
  // Fill 子项分不到非负空间 = 约束系统无解（硬谓词 ConstraintSolvable 的来源）
  if fill_count > 0 && residual < 0.0 {
    failures.push(NegativeResidual(node.id, residual))
  }
  let fill_share : Double = if fill_count > 0 && residual > 0.0 {
    residual / fill_count.to_double()
  } else {
    0.0
  }
  for i in fill_idx.iter() {
    main_sizes[i] = fill_share
  }
  let leftover : Double = if fill_count == 0 && residual > 0.0 {
    residual
  } else {
    0.0
  }
  let main_offset : Double = match l.justify {
    Start => 0.0
    Center => leftover / 2.0
    End => leftover
  }
  let mut cursor : Double = match l.dir {
    Vertical => content.y + main_offset
    Horizontal => content.x + main_offset
  }
  for i in 0..<n {
    let cid = node.children[i]
    let cw = cross_sizes[i]
    let cm = main_sizes[i]
    match doc.nodes.get(cid) {
      Some(child) => {
        let child_rect : Rect = match l.dir {
          Vertical => {
            let x = resolve_pos(child.x, content, cw)
            Rect::new(x, cursor, cw, cm)
          }
          Horizontal => {
            let y = resolve_pos_y(child.y, content, cw)
            Rect::new(cursor, y, cm, cw)
          }
        }
        solve_node(doc, child, child_rect, rects, failures)
      }
      None => ()
    }
    cursor = cursor + cm + l.gap
  }
}

///|
/// 绝对定位求解（Group / 无布局的 Frame）：
/// Fill = 从已解析偏移起填满父矩形剩余空间，因此“正确使用时构造性不溢出”
fn solve_absolute(
  doc : Document,
  node : Node,
  frame : Rect,
  rects : Map[String, Rect],
  failures : Array[SolveFailure],
) -> Unit {
  for cid in node.children.iter() {
    match doc.nodes.get(cid) {
      None => failures.push(MissingNode(cid))
      Some(child) => {
        let x_base : Double = match child.x {
          Fixed(v) => v
          AlignStart(off) => off
          _ => 0.0
        }
        let y_base : Double = match child.y {
          Fixed(v) => v
          AlignStart(off) => off
          _ => 0.0
        }
        let w : Double = match child.width {
          Fixed(v) => v
          Fill => frame.width - x_base
          Hug => intrinsic_size(child, failures).width
        }
        let h : Double = match child.height {
          Fixed(v) => v
          Fill => frame.height - y_base
          Hug => intrinsic_size(child, failures).height
        }
        let x = resolve_pos(child.x, frame, w)
        let y = resolve_pos_y(child.y, frame, h)
        solve_node(doc, child, Rect::new(x, y, w, h), rects, failures)
      }
    }
  }
}
