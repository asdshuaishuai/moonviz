/// 视觉文档模型：唯一事实源（docs/02）。
///
/// 关键设计：
/// - revision 单调递增，补丁必须基于最新 revision 提交（乐观并发控制）。
/// - journal 记录每一次合并。人类操作也被规范化为 Op 写入日志，
///   保证 Agent 读到的永远是完整、规范的代码表示，而不是事件流。

///|
/// 操作来源：两条路线在 journal 里的身份
pub(all) enum OpSource {
  HumanOp
  AgentOp
}

///|
pub fn OpSource::name(self : OpSource) -> String {
  match self {
    HumanOp => "human"
    AgentOp => "agent"
  }
}

///|
pub(all) struct JournalEntry {
  revision : Int
  source : OpSource
  message : String
  violation_count : Int // 合并时携带的视觉债（人类路线可以 > 0）
}

///|
pub(all) struct Document {
  mut root_id : String
  mut nodes : Map[String, Node]
  mut revision : Int
  journal : Array[JournalEntry]
}

///|
pub fn Document::new(viewport : Size) -> Document {
  let root = {
    ..Node::make("root", Frame),
    name: "画布",
    width: Fixed(viewport.width),
    height: Fixed(viewport.height),
    x: Fixed(0.0),
    y: Fixed(0.0),
  }
  let nodes : Map[String, Node] = Map::new()
  nodes.set("root", root)
  { root_id: "root", nodes, revision: 1, journal: [] }
}

///|
pub fn Document::get(self : Document, id : String) -> Node? {
  self.nodes.get(id)
}

///|
pub fn Document::has(self : Document, id : String) -> Bool {
  self.nodes.contains(id)
}

///|
/// 内部插入（不验证）。对外入口一律走补丁（docs/05）。
pub fn Document::insert_node(
  self : Document,
  node : Node,
  parent_id : String,
) -> Bool {
  if self.has(node.id) || !self.has(parent_id) {
    return false
  }
  self.nodes.set(node.id, node)
  match self.nodes.get(parent_id) {
    Some(parent) => {
      let kids = parent.children.copy()
      kids.push(node.id)
      self.nodes.set(parent_id, { ..parent, children: kids })
      true
    }
    None => false
  }
}

///|
/// 直接注册节点到 nodes 表（不挂到任何父；克隆/批量构建用）
pub fn Document::register(self : Document, node : Node) -> Bool {
  if self.has(node.id) {
    return false
  }
  self.nodes.set(node.id, node)
  true
}

///|
pub fn Document::update_node(
  self : Document,
  id : String,
  f : (Node) -> Node,
) -> Bool {
  match self.nodes.get(id) {
    Some(n) => {
      self.nodes.set(id, f(n))
      true
    }
    None => false
  }
}

///|
/// 广度优先找父节点（v1 树很浅，无需缓存父指针）
pub fn Document::find_parent(self : Document, id : String) -> String? {
  let queue : Array[String] = [self.root_id]
  let mut result : String? = None
  let mut running = true
  while running && queue.length() > 0 {
    match queue.pop() {
      None => running = false
      Some(cur) =>
        match self.nodes.get(cur) {
          None => running = false
          Some(n) =>
            for cid in n.children.iter() {
              if cid == id {
                result = Some(cur)
                running = false
              } else {
                queue.push(cid)
              }
            }
        }
    }
  }
  result
}

///|
/// 深拷贝：事务式合并的候选副本（apply 前先在副本上验证，见 docs/05）
pub fn Document::clone(self : Document) -> Document {
  let nodes : Map[String, Node] = Map::new()
  for id in self.nodes.keys() {
    match self.nodes.get(id) {
      Some(n) => nodes.set(id, { ..n, children: n.children.copy() })
      None => ()
    }
  }
  let journal : Array[JournalEntry] = Array::new()
  for e in self.journal.iter() {
    journal.push(e)
  }
  { root_id: self.root_id, nodes, revision: self.revision, journal }
}

///|
/// 示例：登录页（栈布局 + Fill/Hug），与 docs/05 的 Agent 工作流示例一致。
pub fn Document::sample_login() -> Document {
  let doc = Document::new({ width: 390.0, height: 844.0 })
  let root_layout : StackLayout = {
    dir: Vertical,
    gap: 16.0,
    justify: Start,
    padding: Padding::uniform(24.0),
  }
  let _ = doc.update_node("root", fn(r) { { ..r, layout: Some(root_layout) } })
  let title = {
    ..Node::make("title", Text),
    name: "标题",
    text: "欢迎回来",
    width: Hug,
    height: Hug,
    x: AlignStart(0.0),
    y: AlignStart(0.0),
    style: { ..NodeStyle::default(), font_size: 28.0, font_weight: "bold" },
  }
  let input_user = {
    ..Node::make("input-user", Rect),
    name: "用户名输入框",
    width: Fill,
    height: Fixed(44.0),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
    style: { ..NodeStyle::default(), fill: "#F2F3F5", corner_radius: 8.0 },
  }
  let input_pass = {
    ..Node::make("input-pass", Rect),
    name: "密码输入框",
    width: Fill,
    height: Fixed(44.0),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
    style: { ..NodeStyle::default(), fill: "#F2F3F5", corner_radius: 8.0 },
  }
  let btn = {
    ..Node::make("btn-login", Frame),
    name: "登录按钮",
    width: Fill,
    height: Fixed(48.0),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
    layout: Some({
      dir: Horizontal,
      gap: 0.0,
      justify: Center,
      padding: Padding::uniform(0.0),
    }),
    style: { ..NodeStyle::default(), fill: "#4B6BFB", corner_radius: 10.0 },
  }
  let btn_text = {
    ..Node::make("text-btn", Text),
    name: "按钮文字",
    text: "登录",
    width: Hug,
    height: Hug,
    x: CenterInParent,
    y: CenterInParent,
    style: {
      ..NodeStyle::default(),
      font_size: 28.0,
      text_color: "#FFFFFF",
      font_weight: "bold",
    },
  }
  let _ = doc.insert_node(title, "root")
  let _ = doc.insert_node(input_user, "root")
  let _ = doc.insert_node(input_pass, "root")
  let _ = doc.insert_node(btn, "root")
  let _ = doc.insert_node(btn_text, "btn-login")
  doc
}
