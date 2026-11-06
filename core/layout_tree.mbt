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
/// tokens 由调用方（模板构造器）从当前主题传入；缺省出厂令牌保持兼容。
pub fn lt_text(
  id~ : String,
  role~ : String,
  s~ : String,
  tokens? : DesignTokens = DesignTokens::default(),
) -> LT {
  let t = tokens
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
/// 通用盒（面板/背景/插图占位），宽高显式给定。fill/stroke 可传令牌角色名
/// （"primary"/"surface_variant"…，经 tokens 解析）或 #hex 字面量。
pub fn lt_box(
  id~ : String,
  fill~ : String,
  w~ : Double,
  h~ : Double,
  radius? : Double = 12.0,
  shadow? : String = "none",
  stroke? : String = "none",
  tokens? : DesignTokens = DesignTokens::default(),
) -> LT {
  let t = tokens
  {
    node: {
      ..Node::make(id, Rect),
      width: Fixed(w),
      height: Fixed(h),
      style: {
        ..NodeStyle::default(),
        fill: t.resolve_color(fill),
        corner_radius: radius,
        shadow,
        stroke: t.resolve_color(stroke),
      },
    },
    kids: [],
  }
}

///|
/// 弹性盒：吃满剩余空间（用作分隔/自适应留白）。
/// component 标记为 spacer：留白是刻意的空白，不是待填的幽灵组件
/// （渲染层不再给空容器描虚线，结构式布局容器/留白不再像线框稿）。
pub fn lt_flex(id~ : String, fill? : String = "none") -> LT {
  {
    node: {
      ..Node::make(id, Rect),
      component: "spacer",
      width: Fill,
      height: Fill,
      style: { ..NodeStyle::default(), fill, },
    },
    kids: [],
  }
}

///|
/// 按钮（主/次）——颜色查设计令牌，与组件目录 button 同源；文字居中
/// （「按钮族文字默认居中」规范同样约束结构式按钮）
pub fn lt_btn(
  id~ : String,
  label~ : String,
  variant? : String = "primary",
  tokens? : DesignTokens = DesignTokens::default(),
) -> LT {
  let t = tokens
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
        text_align: "center",
      },
      text: label,
    },
    kids: [],
  }
}

///|
/// 输入框（占位文字用 text_hint，描边用 outline——与令牌体系同源）
pub fn lt_input(
  id~ : String,
  ph~ : String,
  tokens? : DesignTokens = DesignTokens::default(),
) -> LT {
  let t = tokens
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
/// 圆形徽标。fill 可传令牌角色名（经 tokens 解析）或 #hex 字面量。
pub fn lt_dot(
  id~ : String,
  fill~ : String,
  d? : Double = 36.0,
  tokens? : DesignTokens = DesignTokens::default(),
) -> LT {
  {
    node: {
      ..Node::make(id, Rect),
      width: Fixed(d),
      height: Fixed(d),
      style: {
        ..NodeStyle::default(),
        fill: tokens.resolve_color(fill),
        corner_radius: 999.0,
      },
    },
    kids: [],
  }
}

///|
/// 白卡（垂直栈 + 现代阴影 + 细边）——底色/描边查令牌。
/// kids 传入子树（回归锚：64bb71d 曾把 kids 误改为 []，登录卡内容整树丢失）。
pub fn lt_card(
  id~ : String,
  gap? : Double = 8.0,
  pad? : Double = 20.0,
  kids? : Array[LT] = [],
  tokens? : DesignTokens = DesignTokens::default(),
) -> LT {
  let t = tokens
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
        // 内容卡用 e1（component_default_shadow 同档）：e2 是临时浮层档，
        // 内容卡压 e2 阴影越级像悬浮弹窗（审计 adaptive_landing 阴影层次）
        shadow: "e1",
      },
    },
    kids,
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
/// 水平居中：形状节点 CenterInParent；Text 节点宽 Fill 时 CenterInParent
/// 不产生位移，同时把 text_align 置 center 让字形在盒内居中（标题/副标题
/// 居中由声明处 .cx() 一处表达，审计 empty_state/login_v2 左偏根因）。
pub fn LT::cx(self : LT) -> LT {
  let align_center = match self.node.kind {
    Text => Some({ ..self.node.style, text_align: "center", })
    _ => None
  }
  match align_center {
    Some(st) =>
      { node: { ..self.node, x: CenterInParent, style: st, }, kids: self.kids, }
    None => { node: { ..self.node, x: CenterInParent, }, kids: self.kids, }
  }
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
