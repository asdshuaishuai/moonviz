/// 文档反序列化：从 Document::to_json 的输出重建文档。
/// save/open（持久化）与 Studio 多文档管理的根基。
///
/// 解析策略：定位式递归下降（引擎其余 JSON 输出同款思路，native 可用无依赖）。
/// to_json 结构：{"revision":N,"root_id":"root","nodes":{嵌套树}}

///|
/// 从 JSON 文本重建 Document（失败返回 Err）
pub fn Document::from_json(text : String) -> Result[Document, String] {
  // 找 nodes 树起点
  let marker = "\"nodes\":"
  let idx = match text.find(marker) {
    Some(i) => i + marker.length()
    None => return Err("json_missing_nodes")
  }
  let body = text.substring(start=idx)
  let store : JsonNodeStore = { nodes: Map::new() }
  match parse_node_obj(body, 0, store) {
    ParseFail(msg) => Err(msg)
    ParseOk(root, _end) => {
      let w = root_fixed(root.width, 390.0)
      let h = root_fixed(root.height, 844.0)
      let doc = Document::new({ width: w, height: h })
      // 树中已注册全部节点（含 root 原id），统一改挂到 "root"
      let rn = { ..root, id: "root", x: Fixed(0.0), y: Fixed(0.0) }
      // 先把 store 里 root 原id 的 children 转移过来
      doc.nodes.set("root", rn)
      remap_children(doc, store, root.id, "root")
      Ok(doc)
    }
  }
}

///|
fn root_fixed(s : SizeSpec, fallback : Double) -> Double {
  match s {
    Fixed(v) => v
    _ => fallback
  }
}

///|
/// parse 期间注册的节点表（id → Node，children id 已带）
struct JsonNodeStore {
  nodes : Map[String, Node]
}

///|
/// 把 store 中 old_root 子树的全部节点注册进 doc（根用 new_id）
fn remap_children(
  doc : Document,
  store : JsonNodeStore,
  old_root : String,
  new_id : String,
) -> Unit {
  match store.nodes.get(old_root) {
    None => ()
    Some(n) =>
      for cid in n.children.iter() {
        match store.nodes.get(cid) {
          None => ()
          Some(child) => {
            let _ = doc.insert_node(child, new_id)
            remap_children(doc, store, cid, cid)
          }
        }
      }
  }
}

///|
enum ParseResult {
  ParseOk(Node, Int)
  ParseFail(String)
}

///|
/// 解析一个节点对象：{"id":...,"kind":...,...,"children":[...]}
/// 整棵子树注册进 store，返回根节点与消费长度
fn parse_node_obj(
  s : String,
  start : Int,
  store : JsonNodeStore,
) -> ParseResult {
  // 必须以 { 开头
  if char_at2(s, start) != "{" {
    return ParseFail("expected_object")
  }
  let mut pos = start + 1
  let mut id = ""
  let mut kind = "frame"
  let mut name = ""
  let mut width : SizeSpec = Fixed(100.0)
  let mut height : SizeSpec = Fixed(100.0)
  let mut x : PosSpec = Fixed(0.0)
  let mut y : PosSpec = Fixed(0.0)
  let mut text = ""
  let mut fill = "none"
  let mut font_size = 14.0
  let mut font_weight = "normal"
  let mut corner_radius = 0.0
  let mut stroke = "none"
  let mut shadow = "none"
  let mut opacity = 1.0
  let mut text_color = "#111111"
  let mut rotate = 0.0
  let mut blur = 0.0
  let mut blend = "normal"
  let mut line_height = 1.5
  let mut tracking = 0.0
  let mut constraint = "lt"
  let mut flip = "none"
  let kids : Array[Node] = []
  let mut seen_children = false
  let n = s.length()
  while pos < n {
    pos = skip_ws2(s, pos)
    if char_at2(s, pos) == "}" {
      pos = pos + 1
      break
    }
    // 字段名
    let (key, p1) = parse_string(s, pos)
    pos = p1
    pos = skip_ws2(s, pos)
    if char_at2(s, pos) != ":" {
      return ParseFail("expected_colon")
    }
    pos = pos + 1
    pos = skip_ws2(s, pos)
    let key_t = unescape_json(key)
    if key_t == "children" {
      seen_children = true
      if char_at2(s, pos) != "[" {
        return ParseFail("children_not_array")
      }
      pos = pos + 1
      while pos < n {
        pos = skip_ws2(s, pos)
        if char_at2(s, pos) == "]" {
          pos = pos + 1
          break
        }
        match parse_node_obj(s, pos, store) {
          ParseFail(e) => return ParseFail(e)
          ParseOk(child, used) => {
            kids.push(child)
            pos = used
          }
        }
        pos = skip_ws2(s, pos)
        if char_at2(s, pos) == "," {
          pos = pos + 1
        }
      }
    } else if key_t == "style" {
      // style 子对象：递归解析全部视觉字段
      if char_at2(s, pos) == "{" {
        let send = skip_object(s, pos)
        let sp = parse_style_obj(s.substring(start=pos, end=send))
        if sp.fill != "" {
          fill = sp.fill
        }
        if sp.stroke != "" {
          stroke = sp.stroke
        }
        corner_radius = sp.radius
        opacity = sp.opacity
        font_size = sp.font_size
        if sp.text_color != "" {
          text_color = sp.text_color
        }
        if sp.font_weight != "" {
          font_weight = sp.font_weight
        }
        if sp.shadow != "" {
          shadow = sp.shadow
        }
        rotate = sp.rotate
        blur = sp.blur
        if sp.blend != "" {
          blend = sp.blend
        }
        if sp.line_height > 0.0 {
          line_height = sp.line_height
        }
        tracking = sp.tracking
        if sp.flip != "" {
          flip = sp.flip
        }
        pos = send
      } else {
        return ParseFail("style_not_object")
      }
    } else if char_at2(s, pos) == "\"" {
      let (v, p2) = parse_string(s, pos)
      pos = p2
      let vt = unescape_json(v)
      match key_t {
        "id" => id = vt
        "kind" => kind = vt
        "name" => name = vt
        "text" => text = vt
        "root_id" => id = "root"
        "fill" => fill = vt
        "stroke" => stroke = vt
        "shadow" => shadow = vt
        "font_weight" => font_weight = vt
        "blend" => blend = vt
        "constraint" => constraint = vt
        "flip" => flip = vt
        _ => ()
      }
    } else {
      // 数值或对象（width/height/x/y 是 spec 对象；font_size 等是数值）
      let (num_or_obj, p3) = parse_value(s, pos)
      pos = p3
      match key_t {
        "font_size" => font_size = num_or_obj.num
        "corner_radius" => corner_radius = num_or_obj.num
        "opacity" => opacity = num_or_obj.num
        "rotate" => rotate = num_or_obj.num
        "blur" => blur = num_or_obj.num
        "line_height" => line_height = num_or_obj.num
        "tracking" => tracking = num_or_obj.num
        "text_color" => text_color = num_or_obj.str
        "width" => width = num_or_obj.spec
        "height" => height = num_or_obj.spec
        "x" => x = num_or_obj.pos
        "y" => y = num_or_obj.pos
        _ => ()
      }
    }
    pos = skip_ws2(s, pos)
    if char_at2(s, pos) == "," {
      pos = pos + 1
    }
  }
  ignore(seen_children)
  let k : NodeKind = match kind {
    "text" => Text
    "rect" => Rect
    "image" => Image
    "group" => Group
    _ => Frame
  }
  let mut node = {
    ..Node::make(if id == "" { "n_auto" } else { id }, k),
    name: if name == "" {
      id
    } else {
      name
    },
    width,
    height,
    x,
    y,
    text,
    style: {
      ..NodeStyle::default(),
      fill,
      stroke,
      corner_radius,
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
    },
    constraint,
  }
  // 注册到 store（父在子之前解析，children 顺序保持）
  let real_id = node.id
  let final_kids : Array[String] = []
  for c in kids.iter() {
    final_kids.push(c.id)
  }
  node = { ..node, children: final_kids }
  store.nodes.set(real_id, node)
  ParseOk(node, pos)
}

///|
/// 解析字符串字面量（含转义），返回原始内容（仍带转义）与结束位置
fn parse_string(s : String, start : Int) -> (String, Int) {
  let sb = StringBuilder::new()
  let mut pos = start + 1 // 跳过开引号
  let n = s.length()
  while pos < n {
    let c = char_at2(s, pos)
    if c == "\\" {
      sb.write_string(char_at2(s, pos + 1))
      pos = pos + 2
    } else if c == "\"" {
      pos = pos + 1
      break
    } else {
      sb.write_string(c)
      pos = pos + 1
    }
  }
  (sb.to_string(), pos)
}

///|
/// 通用值：数值 / spec 对象，返回带类型的中间结构
struct ScalarOrSpec {
  num : Double
  str : String
  spec : SizeSpec
  pos : PosSpec
}

///|
fn parse_value(s : String, start : Int) -> (ScalarOrSpec, Int) {
  let out : ScalarOrSpec = {
    num: 0.0,
    str: "",
    spec: Fixed(0.0),
    pos: Fixed(0.0),
  }
  if char_at2(s, start) == "{" {
    // spec 对象 {"kind":"fixed","value":N}
    let (kind_s, p1) = parse_string_after_key(s, start, "kind")
    let end = skip_object(s, start)
    let kind = unescape_json(kind_s)
    let value = load_number(s.substring(start~, end~), "value")
    let r : ScalarOrSpec = match kind {
      "fixed" => { num: value, str: "", spec: Fixed(value), pos: Fixed(value) }
      "fill" => { num: 0.0, str: "", spec: Fill, pos: Fixed(0.0) }
      "hug" => { num: 0.0, str: "", spec: Hug, pos: Fixed(0.0) }
      "align_start" =>
        { num: value, str: "", spec: Fixed(value), pos: AlignStart(value) }
      "align_end" =>
        { num: value, str: "", spec: Fixed(value), pos: AlignEnd(value) }
      "center" => { num: 0.0, str: "", spec: Fixed(0.0), pos: CenterInParent }
      _ => out
    }
    (r, end)
    // 字符串形式的样式值（text_color 等）
  } else if char_at2(s, start) == "\"" {
    let (v, p) = parse_string(s, start)
    let r : ScalarOrSpec = {
      num: 0.0,
      str: unescape_json(v),
      spec: Fixed(0.0),
      pos: Fixed(0.0),
    }
    (r, p)
  } else {
    // 纯数字
    let mut num = 0.0
    let mut frac = 0.1
    let mut dot = false
    let mut neg = false
    let mut pos = start
    let n = s.length()
    while pos < n {
      let c = char_at2(s, pos)
      let code = char_code2(s, pos)
      if code >= 48 && code <= 57 {
        let d = (code - 48).to_double()
        if dot {
          num = num + d * frac
          frac = frac * 0.1
        } else {
          num = num * 10.0 + d
        }
        pos = pos + 1
      } else if c == "." {
        dot = true
        pos = pos + 1
      } else if c == "-" && num == 0.0 && !dot {
        neg = true
        pos = pos + 1
      } else {
        break
      }
    }
    let r : ScalarOrSpec = {
      num: if neg {
        -num
      } else {
        num
      },
      str: "",
      spec: Fixed(0.0),
      pos: Fixed(0.0),
    }
    (r, pos)
  }
}

///|
/// 在对象里找 "key":"value" 的 value（parse_value 辅助）
fn parse_string_after_key(
  s : String,
  start : Int,
  key : String,
) -> (String, Int) {
  let pattern = "\"" + key + "\":\""
  let sub = s.substring(start~)
  match sub.find(pattern) {
    Some(i) => {
      let vs = i + pattern.length()
      let rest = sub.substring(start=vs)
      match rest.find("\"") {
        Some(e) => (rest.substring(start=0, end=e), start + vs + e)
        None => ("", start)
      }
    }
    None => ("", start)
  }
}

///|
/// 跳过一个完整对象/数组文本，返回结束下标（不含）
fn skip_object(s : String, start : Int) -> Int {
  let mut depth = 0
  let mut pos = start
  let mut in_str = false
  let n = s.length()
  while pos < n {
    let c = char_at2(s, pos)
    if in_str {
      if c == "\\" {
        pos = pos + 2
        continue
      }
      if c == "\"" {
        in_str = false
      }
    } else if c == "\"" {
      in_str = true
    } else if c == "{" || c == "[" {
      depth = depth + 1
    } else if c == "}" || c == "]" {
      depth = depth - 1
      if depth == 0 {
        return pos + 1
      }
    }
    pos = pos + 1
  }
  n
}

///|
/// 从子串里提取 "key": 后面的数字
fn load_number(s : String, key : String) -> Double {
  let pattern = "\"" + key + "\":"
  match s.find(pattern) {
    Some(i) => {
      let rest = s.substring(start=i + pattern.length())
      let mut num = 0.0
      let mut frac = 0.1
      let mut dot = false
      for c in rest.iter() {
        let code = c.to_int()
        if code >= 48 && code <= 57 {
          let d = (code - 48).to_double()
          if dot {
            num = num + d * frac
            frac = frac * 0.1
          } else {
            num = num * 10.0 + d
          }
        } else if code == 46 && !dot {
          dot = true
        } else {
          break
        }
      }
      num
    }
    None => 0.0
  }
}

///|
/// 还原 JSON 转义（\n \t \" \\ 等）
fn unescape_json(s : String) -> String {
  let sb = StringBuilder::new()
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at2(s, i)
    if c == "\\" && i + 1 < n {
      let e = char_at2(s, i + 1)
      match e {
        "n" => sb.write_char('\n')
        "t" => sb.write_char('\t')
        "r" => sb.write_char('\r')
        other => sb.write_string(other)
      }
      i = i + 2
    } else {
      sb.write_string(c)
      i = i + 1
    }
  }
  sb.to_string()
}

///|
fn skip_ws2(s : String, pos : Int) -> Int {
  let n = s.length()
  let mut p = pos
  while p < n {
    let c = char_at2(s, p)
    if c == " " || c == "\n" || c == "\r" || c == "\t" {
      p = p + 1
    } else {
      break
    }
  }
  p
}

///|
fn char_at2(s : String, i : Int) -> String {
  if i < s.length() {
    s.substring(start=i, end=i + 1)
  } else {
    ""
  }
}

///|
/// 取位置 i 处字符的码点（越界返回 0）
fn char_code2(s : String, i : Int) -> Int {
  let mut idx = 0
  for c in s.iter() {
    if idx == i {
      return c.to_int()
    }
    idx = idx + 1
  }
  0
}

///|
/// 解析 style 子对象：返回 (fill, stroke, corner_radius, opacity, font_size,
///                          text_color, font_weight, shadow, rotate, blur, blend,
///                          line_height, tracking)
struct StyleParse {
  fill : String
  stroke : String
  radius : Double
  opacity : Double
  font_size : Double
  text_color : String
  font_weight : String
  shadow : String
  rotate : Double
  blur : Double
  blend : String
  line_height : Double
  tracking : Double
  flip : String
}

///|
fn parse_style_obj(obj : String) -> StyleParse {
  let mut fill = ""
  let mut stroke = ""
  let mut radius = 0.0
  let mut opacity = 1.0
  let mut font_size = 14.0
  let mut text_color = ""
  let mut font_weight = ""
  let mut shadow = ""
  let mut rotate = 0.0
  let mut blur = 0.0
  let mut blend = ""
  let mut line_height = 1.5
  let mut tracking = 0.0
  let mut flip_s = ""
  let n = obj.length()
  let mut pos = 1 // 跳过 {
  while pos < n {
    pos = skip_ws2(obj, pos)
    if char_at2(obj, pos) == "}" {
      break
    }
    let (key, p1) = parse_string(obj, pos)
    pos = p1
    pos = skip_ws2(obj, pos)
    if char_at2(obj, pos) != ":" {
      break
    }
    pos = pos + 1
    pos = skip_ws2(obj, pos)
    let key_t = unescape_json(key)
    if char_at2(obj, pos) == "\"" {
      let (v, p2) = parse_string(obj, pos)
      pos = p2
      let vt = unescape_json(v)
      match key_t {
        "fill" => fill = vt
        "stroke" => stroke = vt
        "text_color" => text_color = vt
        "font_weight" => font_weight = vt
        "shadow" => shadow = vt
        "blend" => blend = vt
        "flip" => flip_s = vt
        _ => ()
      }
    } else {
      let end = value_end(obj, pos)
      let num = parse_num_str(obj.substring(start=pos, end~))
      match key_t {
        "corner_radius" => radius = num
        "opacity" => opacity = num
        "font_size" => font_size = num
        "rotate" => rotate = num
        "blur" => blur = num
        "line_height" => line_height = num
        "tracking" => tracking = num
        _ => ()
      }
      pos = end
    }
    pos = skip_ws2(obj, pos)
    if char_at2(obj, pos) == "," {
      pos = pos + 1
    }
  }
  {
    fill,
    stroke,
    radius,
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
    flip: flip_s,
  }
}

///|
/// 数值 token 结束位置（数字/小数点/负号之外）
fn value_end(s : String, start : Int) -> Int {
  let n = s.length()
  let mut i = start
  while i < n {
    let code = char_code2(s, i)
    if (code >= 48 && code <= 57) || code == 46 || code == 45 {
      i = i + 1
    } else {
      break
    }
  }
  i
}

///|
fn parse_num_str(s : String) -> Double {
  let mut num = 0.0
  let mut frac = 0.1
  let mut dot = false
  let mut neg = false
  for c in s.iter() {
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      let d = (code - 48).to_double()
      if dot {
        num = num + d * frac
        frac = frac * 0.1
      } else {
        num = num * 10.0 + d
      }
    } else if code == 46 && !dot {
      dot = true
    } else if code == 45 && num == 0.0 && !dot {
      neg = true
    } else {
      break
    }
  }
  if neg {
    -num
  } else {
    num
  }
}
