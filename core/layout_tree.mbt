/// 声明式布局树（通用化的核心）：
/// 模板只声明结构（vstack / hstack / 嵌套），几何完全由布局求解器决定。
/// 同一棵树放到 390 或 1280 宽的画布，坐标自动重排——
/// 模板不再是"排好的像素画"，而是可适配任何设备的结构语义。
///
/// 这把"原型"从特定领域产物变成引擎能力：换设备、加内容、改密度，
/// 都不需要重新手排坐标。

///|
/// 布局树：节点本体 + 子树（Document.children 只存 id，构建期用 LT 携带子树）
pub(all) struct LT {
  node : Node
  kids : Array[LT]
}

///|
/// 垂直栈（默认占满父容器，子项沿主轴堆叠）
pub fn lt_v(
  id~ : String,
  gap? : Double = 0.0,
  pad? : Double = 0.0,
  kids? : Array[LT] = [],
) -> LT {
  {
    node: {
      ..Node::make(id, Frame),
      width: Fill,
      height: Fill,
      layout: Some({
        dir: Vertical,
        gap,
        justify: Start,
        padding: Padding::uniform(pad),
      }),
    },
    kids,
  }
}

///|
/// 水平栈（默认占满父容器）
pub fn lt_h(
  id~ : String,
  gap? : Double = 0.0,
  pad? : Double = 0.0,
  kids? : Array[LT] = [],
) -> LT {
  {
    node: {
      ..Node::make(id, Frame),
      width: Fill,
      height: Fill,
      layout: Some({
        dir: Horizontal,
        gap,
        justify: Start,
        padding: Padding::uniform(pad),
      }),
    },
    kids,
  }
}

///|
/// 文本（按排版令牌定字号；宽 Fill 高 Hug）。
/// 字号/文字色一律查 DesignTokens——结构式模板与组件目录、手机模板共用
/// 同一排版体系，不允许本文件自立字号表（双源漂移回归锚）。
pub fn lt_text(id~ : String, role~ : String, s~ : String) -> LT {
  let t = DesignTokens::default()
  let size = match t.resolve_font(role) {
    Some(v) => v
    None =>
      match t.resolve_font("body") {
        Some(v) => v
        None => 14.0
      }
  }
  // 字重无令牌角色，保留本地表（DesignTokens.typography 只有字号）
  let weight : String = match role {
    "h1" | "h2" => "700"
    "h3" | "h4" => "600"
    _ => "400"
  }
  {
    node: {
      ..Node::make(id, Text),
      width: Fill,
      height: Hug,
      style: {
        ..NodeStyle::default(),
        font_size: size,
        font_weight: weight,
        text_color: t.resolve_color("text_primary"),
      },
      text: s,
    },
    kids: [],
  }
}

///|
/// 通用盒（面板/背景/插图占位），宽高显式给定
pub fn lt_box(
  id~ : String,
  fill~ : String,
  w~ : Double,
  h~ : Double,
  radius? : Double = 12.0,
  shadow? : String = "none",
  stroke? : String = "none",
) -> LT {
  {
    node: {
      ..Node::make(id, Rect),
      width: Fixed(w),
      height: Fixed(h),
      style: {
        ..NodeStyle::default(),
        fill,
        corner_radius: radius,
        shadow,
        stroke,
      },
    },
    kids: [],
  }
}

///|
/// 弹性盒：吃满剩余空间（用作分隔/自适应留白）
pub fn lt_flex(id~ : String, fill? : String = "none") -> LT {
  {
    node: {
      ..Node::make(id, Rect),
      width: Fill,
      height: Fill,
      style: { ..NodeStyle::default(), fill, },
    },
    kids: [],
  }
}

///|
/// 按钮（主/次）——颜色查设计令牌，与组件目录 button 同源
pub fn lt_btn(
  id~ : String,
  label~ : String,
  variant? : String = "primary",
) -> LT {
  let t = DesignTokens::default()
  let (fill, tc) : (String, String) = if variant == "primary" {
    (t.resolve_color("primary"), t.resolve_color("on_primary"))
  } else {
    (t.resolve_color("surface_variant"), t.resolve_color("text_primary"))
  }
  {
    node: {
      ..Node::make(id, Rect),
      width: Fixed(if variant == "primary" { 152.0 } else { 140.0 }),
      height: Fixed(44.0),
      style: {
        ..NodeStyle::default(),
        fill,
        text_color: tc,
        corner_radius: 10.0,
        shadow: "e1",
      },
      text: label,
    },
    kids: [],
  }
}

///|
/// 输入框（占位文字用 text_hint，描边用 outline——与令牌体系同源）
pub fn lt_input(id~ : String, ph~ : String) -> LT {
  let t = DesignTokens::default()
  {
    node: {
      ..Node::make(id, Rect),
      width: Fill,
      height: Fixed(46.0),
      style: {
        ..NodeStyle::default(),
        fill: t.resolve_color("surface"),
        text_color: t.resolve_color("text_hint"),
        corner_radius: 10.0,
        stroke: t.resolve_color("outline"),
        shadow: "e1",
      },
      text: ph,
    },
    kids: [],
  }
}

///|
/// 圆形徽标
pub fn lt_dot(id~ : String, fill~ : String, d? : Double = 36.0) -> LT {
  {
    node: {
      ..Node::make(id, Rect),
      width: Fixed(d),
      height: Fixed(d),
      style: { ..NodeStyle::default(), fill, corner_radius: 999.0, },
    },
    kids: [],
  }
}

///|
/// 白卡（垂直栈 + 现代阴影 + 细边）——底色/描边查令牌
pub fn lt_card(
  id~ : String,
  gap? : Double = 8.0,
  pad? : Double = 20.0,
  kids? : Array[LT] = [],
) -> LT {
  let t = DesignTokens::default()
  {
    node: {
      ..Node::make(id, Frame),
      width: Fill,
      height: Fill,
      layout: Some({
        dir: Vertical,
        gap,
        justify: Start,
        padding: Padding::uniform(pad),
      }),
      style: {
        ..NodeStyle::default(),
        fill: t.resolve_color("surface"),
        corner_radius: 14.0,
        stroke: t.resolve_color("outline_variant"),
        shadow: "e2",
      },
    },
    kids: [],
  }
}

///|
/// 微调：主/副轴规格、cross 居中、文字颜色（声明处链式使用）
pub fn LT::w(self : LT, spec : SizeSpec) -> LT {
  { node: { ..self.node, width: spec, }, kids: self.kids, }
}

///|
pub fn LT::h(self : LT, spec : SizeSpec) -> LT {
  { node: { ..self.node, height: spec, }, kids: self.kids, }
}

///|
pub fn LT::cx(self : LT) -> LT {
  { node: { ..self.node, x: CenterInParent, }, kids: self.kids, }
}

///|
pub fn LT::color(self : LT, c : String) -> LT {
  {
    node: { ..self.node, style: { ..self.node.style, text_color: c, }, },
    kids: self.kids,
  }
}

///|
/// 把布局树构建为画板：递归插入，几何交给求解器
pub fn Project::build_artboard(
  self : Project,
  name~ : String,
  width~ : Double,
  height~ : Double,
  tree~ : LT,
) -> String {
  let ab = self.create_artboard(name~, width~, height~)
  match self.artboards.get(ab) {
    Some(art) => {
      // 树根铺满画布（root 是绝对容器）
      let rooted : LT = {
        node: { ..tree.node, x: Fixed(0.0), y: Fixed(0.0), },
        kids: tree.kids,
      }
      lt_insert(art.doc, "root", rooted)
      self.revision = self.revision + 1
    }
    None => ()
  }
  ab
}

///|
/// 递归插入：先挂本节点，再挂子树
fn lt_insert(doc : Document, parent : String, tree : LT) -> Unit {
  let n = tree.node
  let leaf = { ..n, children: [], }
  let _ = doc.insert_node(leaf, parent)
  for k in tree.kids.iter() {
    lt_insert(doc, n.id, k)
  }
}
