///|
test "usercomp: consecutive places on same document" {
  let doc = Document::new({ width: 390.0, height: 844.0 })
  // 手工构造组件 doc：root -> icon_bg -> icon
  let cdoc = Document::new({ width: 64.0, height: 64.0 })
  let icon_bg = {
    ..Node::make("icon_bg", Rect),
    width: Fixed(64.0),
    height: Fixed(64.0),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
    text: "bg",
  }
  let icon = {
    ..Node::make("icon", Text),
    width: Fixed(64.0),
    height: Fixed(20.0),
    x: AlignStart(0.0),
    y: AlignStart(22.0),
    text: "${label}",
  }
  let _ = cdoc.insert_node(icon_bg, "root")
  let _ = cdoc.insert_node(icon, "icon_bg")
  let def : UserComponentDef = {
    id: "mini",
    description: "test",
    category: "user",
    params: [{ name: "label", kind: "text", default_value: "X" }],
    variants: Map::new(),
    default_variant: "default",
    width: 64.0,
    height: 64.0,
    doc: cdoc,
    source: "",
  }
  let r1 = place_user_component(doc, def, "a", dx=10.0, dy=10.0)
  inspect(r1.is_ok(), content="true")
  let r2 = place_user_component(doc, def, "b", dx=100.0, dy=100.0)
  inspect(r2.is_ok(), content="true")
  inspect(doc.has("a::icon_bg"), content="true")
  inspect(doc.has("b::icon_bg"), content="true")
  // 参数代入
  match doc.get("b::icon") {
    Some(n) => inspect(n.text, content="X")
    None => inspect("missing", content="should exist")
  }
}

///|
test "doc: insert child under just-inserted parent" {
  let d = Document::new({ width: 300.0, height: 300.0 })
  let n1 = {
    ..Node::make("x1", Rect),
    width: Fixed(10.0),
    height: Fixed(10.0),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
  }
  let ok1 = d.insert_node(n1, "root")
  inspect(ok1, content="true")
  let n2 = {
    ..Node::make("x2", Text),
    width: Fixed(10.0),
    height: Fixed(10.0),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
  }
  inspect(d.has("x1"), content="true")
  let ok2 = d.insert_node(n2, "x1")
  inspect(ok2, content="true")
}

///|
fn two_inserts_wrapped(d : Document) -> Bool {
  let n1 = {
    ..Node::make("y1", Rect),
    width: Fixed(10.0),
    height: Fixed(10.0),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
  }
  let ok1 = d.insert_node(n1, "root")
  let n2 = {
    ..Node::make("y2", Text),
    width: Fixed(10.0),
    height: Fixed(10.0),
    x: AlignStart(0.0),
    y: AlignStart(0.0),
  }
  let ok2 = d.insert_node(n2, "y1")
  ok1 && ok2
}

///|
test "doc: wrapped two-insert" {
  inspect(two_inserts_wrapped(Document::new({ width: 100.0, height: 100.0 })), content="true")
}
