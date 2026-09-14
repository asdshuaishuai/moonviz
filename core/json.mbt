/// JSON 序列化：Agent 协议的文本面（读取文档、接收结构化错误，docs/05/07）。
/// v1 只做编码；JSON → Patch 的解码在 M1 桥接层（MoonBit JS 后端）落地。

///|
/// JSON 字符串转义（含引号、反斜杠与控制符）。playground 协议层复用。
pub fn json_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// 文档的规范代码表示：嵌套 children 的 JSON 树。
/// Agent 读取这份 JSON 来理解当前设计，然后提交补丁。
pub fn Document::to_json(self : Document) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "{\"revision\":\{self.revision},\"root_id\":\"\{json_escape(self.root_id)}\",\"nodes\":",
  )
  write_node_json(sb, self, self.root_id)
  sb.write_string("}")
  sb.to_string()
}

///|
fn write_node_json(sb : StringBuilder, doc : Document, id : String) -> Unit {
  match doc.nodes.get(id) {
    None => sb.write_string("null")
    Some(n) => {
      let kind : String = match n.kind {
        Frame => "frame"
        Group => "group"
        Rect => "rect"
        Text => "text"
        Image => "image"
      }
      sb.write_string(
        "{\"id\":\"\{json_escape(n.id)}\",\"kind\":\"\{kind}\",\"name\":\"\{json_escape(n.name)}\"," +
        "\"width\":\{size_spec_json(n.width)},\"height\":\{size_spec_json(n.height)}," +
        "\"x\":\{pos_spec_json(n.x)},\"y\":\{pos_spec_json(n.y)},\"text\":\"\{json_escape(n.text)}\"," +
        "\"constraint\":\"\{n.constraint}\"," +
        "\"style\":{\"fill\":\"\{n.style.fill}\",\"stroke\":\"\{n.style.stroke}\",\"corner_radius\":\{n.style.corner_radius},\"opacity\":\{n.style.opacity},\"font_size\":\{n.style.font_size},\"text_color\":\"\{n.style.text_color}\",\"font_weight\":\"\{n.style.font_weight}\",\"shadow\":\"\{n.style.shadow}\",\"rotate\":\{n.style.rotate},\"blur\":\{n.style.blur},\"blend\":\"\{n.style.blend}\",\"line_height\":\{n.style.line_height},\"tracking\":\{n.style.tracking},\"flip\":\"\{n.style.flip}\"},\"children\":[",
      )
      for i in 0..<n.children.length() {
        if i > 0 {
          sb.write_string(",")
        }
        write_node_json(sb, doc, n.children[i])
      }
      sb.write_string("]}")
    }
  }
}

///|
fn size_spec_json(s : SizeSpec) -> String {
  match s {
    Fixed(v) => "{\"kind\":\"fixed\",\"value\":\{v}}"
    Fill => "{\"kind\":\"fill\"}"
    Hug => "{\"kind\":\"hug\"}"
  }
}

///|
fn pos_spec_json(s : PosSpec) -> String {
  match s {
    Fixed(v) => "{\"kind\":\"fixed\",\"value\":\{v}}"
    AlignStart(v) => "{\"kind\":\"align_start\",\"value\":\{v}}"
    AlignEnd(v) => "{\"kind\":\"align_end\",\"value\":\{v}}"
    CenterInParent => "{\"kind\":\"center\"}"
  }
}

///|
pub fn Violation::to_json(self : Violation) -> String {
  "{\"predicate\":\"\{self.predicate.name()}\",\"node_id\":\"\{json_escape(self.node_id)}\",\"detail\":\"\{json_escape(self.detail)}\"}"
}

///|
pub fn PatchError::to_json(self : PatchError) -> String {
  match self {
    StaleBase(cur) =>
      "{\"error\":\"stale_base\",\"current_revision\":\{cur},\"hint\":\"文档已前进，请重新读取后基于最新 revision 提交\"}"
    UnknownNode(id) =>
      "{\"error\":\"unknown_node\",\"node_id\":\"\{json_escape(id)}\"}"
    UnknownParent(id) =>
      "{\"error\":\"unknown_parent\",\"node_id\":\"\{json_escape(id)}\"}"
    DuplicateId(id) =>
      "{\"error\":\"duplicate_id\",\"node_id\":\"\{json_escape(id)}\"}"
    HierarchyError(msg) =>
      "{\"error\":\"hierarchy_error\",\"detail\":\"\{json_escape(msg)}\"}"
    StructuralBlock(vs) => block_json("structural_block", vs)
    HardBlock(vs) => block_json("hard_block", vs)
  }
}

///|
fn block_json(kind : String, vs : Array[Violation]) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\"error\":\"\{kind}\",\"violations\":[")
  for i in 0..<vs.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(vs[i].to_json())
  }
  sb.write_string("]}")
  sb.to_string()
}
