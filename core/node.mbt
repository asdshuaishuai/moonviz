/// 场景图节点模型（docs/02）。
/// children 只存 id，节点本体统一放在 Document.nodes 的平铺表里——
/// 这让补丁、日志、JSON 导出都以 id 为键，人类与 Agent 共享同一份表示。

///|
/// 节点种类
pub(all) enum NodeKind {
  Frame // 容器：可携带栈布局，子节点按布局或绝对定位排布
  Group // 透明容器：仅分组，子节点一律绝对定位
  Rect // 矩形
  Text // 文本
  Image // 图片（v1 渲染为占位矩形）
}

///|
/// 尺寸规格：Fixed 定值 / Fill 占满可用空间 / Hug 包裹内容
pub(all) enum SizeSpec {
  Fixed(Double)
  Fill
  Hug
}

///|
/// 位置规格（相对父容器内容盒；栈布局中主轴分量被忽略，由布局游标决定）
pub(all) enum PosSpec {
  Fixed(Double)
  AlignStart(Double) // 距内容盒 start 边的偏移
  AlignEnd(Double) // 距内容盒 end 边的偏移
  CenterInParent
}

///|
pub(all) enum StackDir {
  Vertical
  Horizontal
}

///|
/// 主轴对齐：剩余空间（无 Fill 子项时）如何分配
pub(all) enum Justify {
  Start
  Center
  End
}

///|
pub(all) struct Padding {
  top : Double
  right : Double
  bottom : Double
  left : Double
}

///|
pub fn Padding::uniform(v : Double) -> Padding {
  { top: v, right: v, bottom: v, left: v }
}

///|
/// 栈布局：Figma Auto Layout 的最小可用子集
pub(all) struct StackLayout {
  dir : StackDir
  gap : Double
  justify : Justify
  padding : Padding
}

///|
/// 视觉样式（v3：Paint DSL 渐变 / 旋转 / 模糊 / 混合 / 排版细节）
pub(all) struct NodeStyle {
  fill : String
  stroke : String
  stroke_width : Double
  corner_radius : Double
  opacity : Double
  font_size : Double
  text_color : String
  font_weight : String
  shadow : String // "none" | "e1" | "e2" | "e3"
  rotate : Double // 旋转角度（度，绕节点中心）
  blur : Double // 层模糊半径 px（0 = 无）
  blend : String // 混合模式 "normal"|"multiply"|"screen"|"overlay"
  line_height : Double // 文本行高倍数（默认 1.5）
  tracking : Double // 字距（em）
  flip : String // "none" | "h" | "v" | "both"
}

///|
pub fn NodeStyle::default() -> NodeStyle {
  {
    fill: "none",
    stroke: "none",
    stroke_width: 0.0,
    corner_radius: 0.0,
    opacity: 1.0,
    font_size: 14.0,
    text_color: "#111111",
    font_weight: "normal",
    shadow: "none",
    rotate: 0.0,
    blur: 0.0,
    blend: "normal",
    line_height: 1.5,
    tracking: 0.0,
    flip: "none",
  }
}

///|
pub(all) struct Node {
  id : String
  kind : NodeKind
  name : String
  /// 语义组件名（"button" / "text_input" / "frame"...）：
  /// decl 声明文本序列化/解析据此保留组件语义，编辑器组件库也用它
  component : String
  width : SizeSpec
  height : SizeSpec
  x : PosSpec
  y : PosSpec
  layout : StackLayout? // 仅 Frame 使用；None = 绝对定位容器
  style : NodeStyle
  text : String // 仅 Text 使用；Rect 上非空为居中标签
  children : Array[String]
  constraint : String // 父容器 resize 时的适配约束（Figma Constraints）：
  // 水平 lt|ct|rt|stretch|hscale + 垂直组合，如 "lt" "rt" "ct" "cb" "stretch-c" "hscale-m"
}

///|
fn kind_component(kind : NodeKind) -> String {
  match kind {
    Frame => "frame"
    Group => "group"
    Rect => "rect"
    Text => "text"
    Image => "image"
  }
}

///|
/// 带默认值的节点工厂，配合结构更新语法使用：{ ..Node::make(id, kind), ... }
pub fn Node::make(id : String, kind : NodeKind) -> Node {
  {
    id,
    kind,
    name: id,
    component: kind_component(kind),
    width: Fixed(100.0),
    height: Fixed(100.0),
    x: Fixed(0.0),
    y: Fixed(0.0),
    layout: None,
    style: NodeStyle::default(),
    text: "",
    children: [],
    constraint: "lt",
  }
}

///|
/// 文本内在尺寸估算（v1：CJK 全角按 1.0 倍字号，其余 0.6 倍；行高 1.5）。
/// M2 计划：编辑器运行时用 canvas measureText 实测后写入文档，见 docs/03。
pub const TEXT_LINE_HEIGHT_RATIO : Double = 1.5

///|
pub const CJK_CODEPOINT_MIN : Int = 0x2E80

///|
pub const ASCII_ADVANCE_RATIO : Double = 0.6

///|
fn char_advance(code : Int, font_size : Double) -> Double {
  if code >= CJK_CODEPOINT_MIN {
    font_size
  } else {
    font_size * ASCII_ADVANCE_RATIO
  }
}

///|
pub fn text_intrinsic(
  text : String,
  font_size : Double,
  line_height? : Double = 1.5,
) -> Size {
  // 多行：取最宽行，高度 = 行数 × 行高
  let mut max_w = 0.0
  let mut lines = 0
  let mut line_w = 0.0
  for c in text.iter() {
    if c == '\n' {
      if line_w > max_w {
        max_w = line_w
      }
      line_w = 0.0
      lines = lines + 1
    } else {
      line_w = line_w + char_advance(c.to_int(), font_size)
    }
  }
  if line_w > max_w {
    max_w = line_w
  }
  lines = lines + 1
  let w = if max_w == 0.0 { font_size * ASCII_ADVANCE_RATIO } else { max_w }
  { width: w, height: font_size * line_height * lines.to_double() }
}
