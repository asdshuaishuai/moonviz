/// 原型声明 DSL（docs/02）：`.mbt.md` 代码块使用的公开 API。
///
/// Agent 在 `.mbt.md` 的 ```mbt check``` 代码块里用这些函数声明原型；
/// 声明即代码，随 `moon check` / `moon test` 获得完整的编译与测试保障。
/// `.mbt.md` 代码块按黑盒测试处理，因此只能使用本包公开 API
/// （`@decl.xxx`）——组件工厂把 `moonviz/core` 的细节封装在此。

///|
/// 组件工厂：文本（Hug 包裹内容）
pub fn text(
  id~ : String,
  content~ : String,
  size? : Double = 14.0,
  weight? : String = "normal",
  color? : String = "#111111",
) -> @core.Node {
  {
    ..@core.Node::make(id, @core.Text),
    name: id,
    text: content,
    width: @core.Hug,
    height: @core.Hug,
    x: @core.AlignStart(0.0),
    y: @core.AlignStart(0.0),
    style: {
      ..@core.NodeStyle::default(),
      font_size: size,
      font_weight: weight,
      text_color: color,
    },
  }
}

///|
/// 组件工厂：单行输入框（矩形 + 占位文字，宽度语义由调用方决定）
pub fn text_input(
  id~ : String,
  width~ : @core.SizeSpec,
  height~ : @core.SizeSpec,
  placeholder? : String = "",
) -> @core.Node {
  {
    ..@core.Node::make(id, @core.Rect),
    name: id,
    component: "text_input",
    width,
    height,
    x: @core.AlignStart(0.0),
    y: @core.AlignStart(0.0),
    text: placeholder,
    style: {
      ..@core.NodeStyle::default(),
      fill: "#F2F3F5",
      corner_radius: 8.0,
      text_color: "#9CA3AF",
      font_size: 14.0,
    },
  }
}

///|
/// 组件工厂：按钮（矩形 + 居中标签）
pub fn button(
  id~ : String,
  width~ : @core.SizeSpec,
  height~ : @core.SizeSpec,
  label? : String = "按钮",
) -> @core.Node {
  {
    ..@core.Node::make(id, @core.Rect),
    name: id,
    component: "button",
    width,
    height,
    x: @core.AlignStart(0.0),
    y: @core.AlignStart(0.0),
    text: label,
    style: {
      ..@core.NodeStyle::default(),
      fill: "#4B6BFB",
      corner_radius: 10.0,
      text_color: "#FFFFFF",
      font_size: 16.0,
      font_weight: "bold",
    },
  }
}

///|
/// 组件工厂：任意矩形
pub fn rect(
  id~ : String,
  width~ : @core.SizeSpec,
  height~ : @core.SizeSpec,
  fill? : String = "#EEEEEE",
  radius? : Double = 0.0,
) -> @core.Node {
  {
    ..@core.Node::make(id, @core.Rect),
    name: id,
    width,
    height,
    x: @core.AlignStart(0.0),
    y: @core.AlignStart(0.0),
    style: { ..@core.NodeStyle::default(), fill, corner_radius: radius },
  }
}

///|
/// 通用节点工厂：用于规范序列化，保留组件语义、位置、尺寸与样式。
pub fn generic_node(
  id~ : String,
  component~ : String,
  width~ : @core.SizeSpec,
  height~ : @core.SizeSpec,
  kind? : String = "frame",
  x? : Double = 0.0,
  y? : Double = 0.0,
  text? : String = "",
  layout? : @core.StackLayout? = None,
  fill? : String = "none",
  stroke? : String = "none",
  stroke_width? : Double = 0.0,
  radius? : Double = 0.0,
  opacity? : Double = 1.0,
  font_size? : Double = 14.0,
  text_color? : String = "#111111",
  font_weight? : String = "normal",
  shadow? : String = "none",
  rotate? : Double = 0.0,
  blur? : Double = 0.0,
  blend? : String = "normal",
  line_height? : Double = 1.5,
  tracking? : Double = 0.0,
  flip? : String = "none",
  constraint? : String = "lt",
  text_align? : String = "left",
  font_style? : String = "normal",
  stroke_dash? : String = "solid",
  visible? : Bool = true,
  name? : String = "",
) -> @core.Node {
  let node_kind = match kind {
    "text" => @core.Text
    "image" => @core.Image
    "group" => @core.Group
    "rect" => @core.Rect
    _ => @core.Frame
  }
  {
    ..@core.Node::make(id, node_kind),
    name: if name == "" { id } else { name },
    component,
    width,
    height,
    x: @core.AlignStart(x),
    y: @core.AlignStart(y),
    text,
    layout,
    constraint,
    style: {
      ..@core.NodeStyle::default(),
      fill,
      stroke,
      stroke_width,
      corner_radius: radius,
      opacity,
      font_size,
      text_color,
      font_weight,
      shadow,
      rotate,
      blur,
      blend,
      line_height,
      tracking,
      flip,
      text_align,
      font_style,
      stroke_dash,
      visible,
    },
  }
}

///|
/// 组件工厂：容器（可携带栈布局）
pub fn frame(
  id~ : String,
  width~ : @core.SizeSpec,
  height~ : @core.SizeSpec,
  layout? : @core.StackLayout? = None,
  fill? : String = "none",
) -> @core.Node {
  {
    ..@core.Node::make(id, @core.Frame),
    name: id,
    width,
    height,
    x: @core.AlignStart(0.0),
    y: @core.AlignStart(0.0),
    layout,
    style: { ..@core.NodeStyle::default(), fill, },
  }
}

///|
/// 组件工厂：透明分组（子节点自由摆放）
pub fn group(id~ : String) -> @core.Node {
  {
    ..@core.Node::make(id, @core.Group),
    name: id,
    width: @core.Fill,
    height: @core.Fill,
    x: @core.AlignStart(0.0),
    y: @core.AlignStart(0.0),
  }
}

///|
/// 组件工厂：图片（v1 渲染为占位矩形）
pub fn image(
  id~ : String,
  width~ : @core.SizeSpec,
  height~ : @core.SizeSpec,
) -> @core.Node {
  {
    ..@core.Node::make(id, @core.Image),
    name: id,
    width,
    height,
    x: @core.AlignStart(0.0),
    y: @core.AlignStart(0.0),
  }
}

///|
/// 栈布局描述：flex(direction=Vertical, gap=16, padding=24)
pub fn flex(
  direction~ : @core.StackDir,
  gap? : Double = 0.0,
  padding? : Double = 0.0,
  justify? : @core.Justify = @core.Start,
) -> @core.StackLayout {
  { dir: direction, gap, justify, padding: @core.Padding::uniform(padding) }
}

///|
/// 词汇别名：让声明代码与设计语义一一对应
pub let vertical : @core.StackDir = @core.Vertical

///|
pub let horizontal : @core.StackDir = @core.Horizontal

///|
pub let fill : @core.SizeSpec = @core.Fill

///|
pub let hug : @core.SizeSpec = @core.Hug

///|
pub let justify_start : @core.Justify = @core.Start

///|
pub let justify_center : @core.Justify = @core.Center

///|
pub let justify_end : @core.Justify = @core.End

///|
pub fn fixed(v : Double) -> @core.SizeSpec {
  @core.Fixed(v)
}

///|
/// 原型声明：.mbt.md 代码块的构建目标，编译产物即内存文档
pub struct Prototype {
  name : String
  mut root : @core.Node
  index : Map[String, @core.Node]
}

///|
/// 创建原型：视口尺寸即根 Frame 尺寸
pub fn prototype(
  name~ : String,
  width? : Double = 390.0,
  height? : Double = 844.0,
) -> Prototype {
  let root = {
    ..@core.Node::make("root", @core.Frame),
    name,
    width: @core.Fixed(width),
    height: @core.Fixed(height),
    x: @core.Fixed(0.0),
    y: @core.Fixed(0.0),
  }
  let index : Map[String, @core.Node] = Map::new()
  index.set("root", root)
  { name, root, index }
}

///|
/// 设置根容器的栈布局
pub fn Prototype::set_layout(self : Prototype, l : @core.StackLayout) -> Unit {
  self.root = { ..self.root, layout: Some(l) }
  self.index.set("root", self.root)
}

///|
/// 追加节点到根容器
pub fn Prototype::add(self : Prototype, node : @core.Node) -> Unit {
  self.add_to(parent_id="root", node~)
}

///|
/// 追加节点到指定容器
pub fn Prototype::add_to(
  self : Prototype,
  parent_id~ : String,
  node~ : @core.Node,
) -> Unit {
  if self.index.contains(node.id) {
    abort("prototype: 节点 id 重复 \{node.id}")
  }
  self.index.set(node.id, node)
  match self.index.get(parent_id) {
    Some(p) => {
      let kids = p.children.copy()
      kids.push(node.id)
      let updated = { ..p, children: kids }
      self.index.set(parent_id, updated)
      if parent_id == self.root.id {
        self.root = updated
      }
    }
    None => abort("prototype: 未知父节点 \{parent_id}")
  }
}

///|
/// 声明 → 内存文档（Scene Graph）。这是 .mbt.md 事实源的编译产物，
/// 布局、谓词、渲染都在这份文档上进行。
pub fn Prototype::build(self : Prototype) -> @core.Document {
  let w : Double = match self.root.width {
    @core.Fixed(v) => v
    _ => 390.0
  }
  let h : Double = match self.root.height {
    @core.Fixed(v) => v
    _ => 844.0
  }
  let doc = @core.Document::new({ width: w, height: h })
  let nodes : Map[String, @core.Node] = Map::new()
  for id in self.index.keys() {
    match self.index.get(id) {
      Some(n) => nodes.set(id, { ..n, children: n.children.copy() })
      None => ()
    }
  }
  doc.nodes = nodes
  doc.root_id = self.root.id
  doc.revision = 1
  doc
}

///|
/// “不崩”谓词检查（MVP：运行时断言层；moon prove 为实验性，后续迁移，见 docs/04）
pub fn Prototype::check(self : Prototype) -> Array[@core.Violation] {
  @core.validate(self.build())
}

///|
/// 渲染为 SVG（主渲染路径）
pub fn Prototype::render(self : Prototype) -> String {
  @core.render_svg(self.build())
}

// ---------------------------------------------------------------------------
// 文档 → Prototype（人类路线落盘后 Agent 反向读取用）
// ---------------------------------------------------------------------------

///|
fn doc_walk(doc : @core.Document, page : Prototype, pid : String) -> Unit {
  match doc.nodes.get(pid) {
    None => ()
    Some(pn) =>
      for cid in pn.children.iter() {
        match doc.nodes.get(cid) {
          Some(cn) => {
            // children 必须清空：add_to 入库后由子节点的 add_to 重新累积。
            // 若保留 doc 侧 children，容器节点的子级会被计入两次，
            // canonical 声明文本随之翻倍（结构式模板导出即损坏）。
            let clean = { ..cn, children: [] }
            page.add_to(parent_id=pid, node=clean)
            doc_walk(doc, page, cid)
          }
          None => ()
        }
      }
  }
}

///|
/// 文档 → 声明原型的正向重建（人类操作通过 patch 落内存文档后，
/// 由这里重新生成规范声明文本，双向同步闭环）。
pub fn from_document(doc : @core.Document) -> Prototype {
  match doc.nodes.get(doc.root_id) {
    None => abort("from_document: 缺少根节点")
    Some(root) => {
      let w : Double = match root.width {
        @core.Fixed(v) => v
        _ => 390.0
      }
      let h : Double = match root.height {
        @core.Fixed(v) => v
        _ => 844.0
      }
      let page = prototype(name=root.name, width=w, height=h)
      let rl : @core.StackLayout? = root.layout
      doc_walk(doc, page, "root")
      // 还原根布局（prototype() 不带 layout）
      match rl {
        Some(l) => page.set_layout(l)
        None => ()
      }
      page
    }
  }
}
