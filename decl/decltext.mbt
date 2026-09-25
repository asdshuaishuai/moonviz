/// 声明文本往返（docs/02）：`.mbt.md` 代码块内容的规范序列化与解析。
///
/// 引擎据此完成同步管道的两个方向：
/// - 人类操作 → `to_decl_text`：文档被投影回规范声明文本（.mbt.md 落盘内容）
/// - Agent 编辑 → `parse_decl`：声明文本解析回 Prototype，经谓词后生效
///
/// v1 规范形式约束：
/// - 位置表达 AlignStart（裸数字）/ CenterInParent（@decl.center）/ AlignEnd（@decl.end(n)）。
/// - padding 仅 uniform（与 flex 工厂一致）。
/// - 字符串值内不允许出现裸逗号/裸括号；引号与反斜杠会被转义并正确还原。
/// - 组件凭 `component` 语义名还原（button/text_input → rect + 文字标签）。

///|
/// 解析错误：1 起始的行号 + 消息（Agent 修复循环的输入）
pub(all) struct DeclParseError {
  line : Int
  message : String
}

///|
pub fn DeclParseError::describe(self : DeclParseError) -> String {
  "第 \{self.line} 行：\{self.message}"
}

///|
/// Prototype 上的人类语义操作（playground 拖拽走这里）
pub fn Prototype::move_node(
  self : Prototype,
  id~ : String,
  x~ : Double,
  y~ : Double,
) -> Result[Unit, String] {
  match self.index.get(id) {
    Some(n) => {
      let updated = { ..n, x: @core.AlignStart(x), y: @core.AlignStart(y) }
      self.index.set(id, updated)
      if id == self.root.id {
        self.root = updated
      }
      Ok(())
    }
    None => Err("move_node: 未知节点 \{id}")
  }
}

///|
const PROTO_PREFIX : String = "let page = @decl.prototype("

///|
const LAYOUT_PREFIX : String = "page.set_layout("

///|
const ADD_PREFIX : String = "page.add("

///|
const ADD_TO_PREFIX : String = "page.add_to(parent_id=\""

///|
const NODE_MARKER : String = "node=@decl."

///|
const DECL_MARKER : String = "@decl."

///|
const FLEX_MARKER : String = "flex("

///|
const COMMA : String = ","

///|
/// has_prefix 的纯 String 实现（避免 StringView 边界）
fn has_prefix_str(s : String, prefix : String) -> Bool {
  s.length() >= prefix.length() &&
  s.substring(start=0, end=prefix.length()) == prefix
}

// ---------------------------------------------------------------------------
// 通用小件
// ---------------------------------------------------------------------------

///|
fn join_with(parts : Array[String], sep : String) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(sep)
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

///|
fn lines_of(text : String) -> Array[String] {
  let out : Array[String] = Array::new()
  let mut buf = StringBuilder::new()
  for c in text.iter() {
    if c == '\n' {
      out.push(buf.to_string())
      buf = StringBuilder::new()
    } else {
      buf.write_char(c)
    }
  }
  out.push(buf.to_string())
  out
}

///|
fn is_blank(s : String) -> Bool {
  let mut blank = true
  for c in s.iter() {
    if c != ' ' && c != '\t' {
      blank = false
    }
  }
  blank
}

///|
/// 去首尾空格（substring 索引按 UTF-16 计；本文本域为 ASCII 空白）
fn trim_spaces(s : String) -> String {
  match s.find_by(fn(c) { c != ' ' }) {
    None => ""
    Some(a) => {
      let mut b = s.length() - 1
      let mut end = a
      let mut running = true
      while b >= a && running {
        match s.get_char(b) {
          Some(c) =>
            if c != ' ' {
              end = b
              running = false
            } else {
              b = b - 1
            }
          None => running = false
        }
      }
      s.substring(start=a, end=end + 1)
    }
  }
}

///|
/// 括号深度感知的逗号切分（顶层逗号才是分隔符）。
/// 引号感知：双引号内的 `,()` 不参与切分/计数；`\x` 转义序列原样保留。
fn split_params(s : String) -> Array[String] {
  let out : Array[String] = Array::new()
  let mut depth = 0
  let mut in_quotes = false
  let mut esc = false
  let mut buf = StringBuilder::new()
  for c in s.iter() {
    if esc {
      buf.write_char('\\')
      buf.write_char(c)
      esc = false
      continue
    }
    match c {
      '\\' if in_quotes => esc = true
      '"' => {
        in_quotes = !in_quotes
        buf.write_char(c)
      }
      '(' | ')' if !in_quotes => {
        if c == '(' {
          depth = depth + 1
        } else {
          depth = depth - 1
        }
        buf.write_char(c)
      }
      ',' if !in_quotes && depth == 0 => {
        out.push(buf.to_string())
        buf = StringBuilder::new()
      }
      _ => buf.write_char(c)
    }
  }
  if !is_blank(buf.to_string()) {
    out.push(buf.to_string())
  }
  out
}

///|
/// 委托 core（转义还原已上移，供操作语法共用）
pub fn unescape_value(s : String) -> String {
  @core.unescape_value(s)
}

///|
/// 还原声明转义：\" \\ \, \( \) \n \r \t
fn unescape_decl(s : String) -> String {
  let sb = StringBuilder::new()
  let mut esc = false
  for c in s.iter() {
    match esc {
      true => {
        match c {
          '"' => sb.write_char('"')
          '\\' => sb.write_char('\\')
          ',' => sb.write_char(',')
          '(' => sb.write_char('(')
          ')' => sb.write_char(')')
          'n' => sb.write_char('\n')
          'r' => sb.write_char('\r')
          't' => sb.write_char('\t')
          other => {
            sb.write_char('\\')
            sb.write_char(other)
          }
        }
        esc = false
      }
      false =>
        match c {
          '\\' => esc = true
          other => sb.write_char(other)
        }
    }
  }
  sb.to_string()
}

///|
fn parse_number(s : String) -> Double? {
  let body : String = if s.length() > 0 && s.get_char(0) == Some('-') {
    s.substring(start=1)
  } else {
    s
  }
  let dot : Int? = body.find(".")
  let int_part : String = match dot {
    Some(i) => body.substring(start=0, end=i)
    None => body
  }
  let frac_part : String = match dot {
    Some(i) => body.substring(start=i + 1)
    None => "0"
  }
  let mut acc = 0
  for c in int_part.iter() {
    let code = c.to_int()
    if code < 48 || code > 57 {
      return None
    }
    acc = acc * 10 + (code - 48)
  }
  let mut frac = 0.0
  let mut scale = 0.1
  for c in frac_part.iter() {
    let code = c.to_int()
    if code < 48 || code > 57 {
      return None
    }
    frac = frac + (code - 48).to_double() * scale
    scale = scale / 10.0
  }
  let value = acc.to_double() + frac
  if s.length() > 0 && s.get_char(0) == Some('-') {
    Some(-value)
  } else {
    Some(value)
  }
}

// ---------------------------------------------------------------------------
// 序列化：Prototype → 规范声明文本
// ---------------------------------------------------------------------------

///|
/// 声明字符串转义：在 JSON 转义（" \\ \n \r \t）之上追加声明语法保留字
/// `,` `(` `)`，保证含逗号/括号的文本在 split_params 往返后语义不变。
fn decl_escape(s : String) -> String {
  let escaped = @core.json_escape(s)
  let sb = StringBuilder::new()
  for c in escaped.iter() {
    match c {
      ',' => sb.write_string("\\,")
      '(' => sb.write_string("\\(")
      ')' => sb.write_string("\\)")
      other => sb.write_char(other)
    }
  }
  sb.to_string()
}

///|
fn num_text(v : Double) -> String {
  v.to_string()
}

///|
fn size_text(s : @core.SizeSpec) -> String {
  match s {
    @core.Fill => "@decl.fill"
    @core.Hug => "@decl.hug"
    @core.Fixed(v) => "@decl.fixed(\{num_text(v)})"
  }
}

///|
fn pos_text(spec : @core.PosSpec) -> String? {
  match spec {
    @core.AlignStart(v) => if v != 0.0 { Some(num_text(v)) } else { None }
    @core.Fixed(v) => if v != 0.0 { Some(num_text(v)) } else { None }
    @core.CenterInParent => Some(DECL_MARKER + "center")
    @core.AlignEnd(v) => Some(DECL_MARKER + "end(" + num_text(v) + ")")
  }
}

///|
/// 位置规格解析："@decl.center" → CenterInParent；"@decl.end(24)" → AlignEnd(24)；
/// "@decl.start(24)" / 裸数字 → AlignStart（default 形式）。
fn pos_val(v : String, line : Int) -> Result[@core.PosSpec, DeclParseError] {
  let body : String = if has_prefix_str(v, DECL_MARKER) {
    v.substring(start=DECL_MARKER.length())
  } else {
    v
  }
  if body == "center" {
    Ok(@core.CenterInParent)
  } else if has_prefix_str(body, "end(") && body.length() > 5 {
    match parse_number(body.substring(start=4, end=body.length() - 1)) {
      Some(d) => Ok(@core.AlignEnd(d))
      None => Err({ line, message: "无法解析 end 位置 \{body}" })
    }
  } else if has_prefix_str(body, "start(") && body.length() > 7 {
    match parse_number(body.substring(start=6, end=body.length() - 1)) {
      Some(d) => Ok(@core.AlignStart(d))
      None => Err({ line, message: "无法解析 start 位置 \{body}" })
    }
  } else {
    match parse_number(body) {
      Some(d) => Ok(@core.AlignStart(d))
      None => Err({ line, message: "无法解析位置规格 \{body}" })
    }
  }
}

///|
fn dir_text(d : @core.StackDir) -> String {
  match d {
    @core.Vertical => "@decl.vertical"
    @core.Horizontal => "@decl.horizontal"
  }
}

///|
fn justify_text(j : @core.Justify) -> String {
  match j {
    @core.Start => "@decl.justify_start"
    @core.Center => "@decl.justify_center"
    @core.End => "@decl.justify_end"
  }
}

///|
fn flex_text(l : @core.StackLayout) -> String {
  "@decl.flex(direction=\{dir_text(l.dir)}, gap=\{num_text(l.gap)}, padding=\{num_text(l.padding.top)}, justify=\{justify_text(l.justify)})"
}

///|
fn node_call(n : @core.Node) -> String {
  let parts = Array::new()
  parts.push("id=\"\{decl_escape(n.id)}\"")
  parts.push("component=\"\{decl_escape(n.component)}\"")
  let kind = match n.kind {
    @core.Frame => "frame"
    @core.Group => "group"
    @core.Rect => "rect"
    @core.Text => "text"
    @core.Image => "image"
  }
  parts.push("kind=\"\{kind}\"")
  parts.push("width=\{size_text(n.width)}")
  parts.push("height=\{size_text(n.height)}")
  match pos_text(n.x) {
    Some(v) => parts.push("x=\{v}")
    None => ()
  }
  match pos_text(n.y) {
    Some(v) => parts.push("y=\{v}")
    None => ()
  }
  match n.layout {
    Some(layout) => parts.push("layout=\{flex_text(layout)}")
    None => ()
  }
  parts.push("text=\"\{decl_escape(n.text)}\"")
  parts.push("fill=\"\{decl_escape(n.style.fill)}\"")
  parts.push("stroke=\"\{decl_escape(n.style.stroke)}\"")
  parts.push("stroke_width=\{num_text(n.style.stroke_width)}")
  parts.push("radius=\{num_text(n.style.corner_radius)}")
  parts.push("opacity=\{num_text(n.style.opacity)}")
  parts.push("font_size=\{num_text(n.style.font_size)}")
  parts.push("text_color=\"\{decl_escape(n.style.text_color)}\"")
  parts.push("font_weight=\"\{decl_escape(n.style.font_weight)}\"")
  parts.push("shadow=\"\{decl_escape(n.style.shadow)}\"")
  parts.push("rotate=\{num_text(n.style.rotate)}")
  parts.push("blur=\{num_text(n.style.blur)}")
  parts.push("blend=\"\{decl_escape(n.style.blend)}\"")
  parts.push("line_height=\{num_text(n.style.line_height)}")
  parts.push("tracking=\{num_text(n.style.tracking)}")
  parts.push("flip=\"\{decl_escape(n.style.flip)}\"")
  parts.push("text_align=\"\{decl_escape(n.style.text_align)}\"")
  parts.push("font_style=\"\{decl_escape(n.style.font_style)}\"")
  parts.push("stroke_dash=\"\{decl_escape(n.style.stroke_dash)}\"")
  parts.push("visible=\{n.style.visible}")
  // overlay 仅在声明时写出——保持既有 canonical 文本零扰动
  if n.style.overlay {
    parts.push("overlay=true")
  }
  parts.push("constraint=\"\{decl_escape(n.constraint)}\"")
  // name 仅在偏离 id 时输出（交互标记写在这里，缺省即 id，避免每行冗余）
  if n.name != n.id {
    parts.push("name=\"\{decl_escape(n.name)}\"")
  }
  "@decl.generic_node(\{join_with(parts, COMMA)})"
}

///|
fn emit_children(
  proto : Prototype,
  sb : StringBuilder,
  pid : String,
  toplevel : Bool,
) -> Unit {
  match proto.index.get(pid) {
    Some(parent) =>
      for cid in parent.children.iter() {
        match proto.index.get(cid) {
          Some(child) => {
            let call = node_call(child)
            if toplevel {
              sb.write_string("page.add(\{call})\n")
            } else {
              sb.write_string(
                "page.add_to(parent_id=\"\{pid}\", node=\{call})\n",
              )
            }
          }
          None => ()
        }
        emit_children(proto, sb, cid, false)
      }
    None => ()
  }
}

///|
/// Prototype → 规范声明文本（.mbt.md 代码块全文）
pub fn Prototype::to_decl_text(self : Prototype) -> String {
  let sb = StringBuilder::new()
  let root = self.root
  let w : Double = match root.width {
    @core.Fixed(v) => v
    _ => 390.0
  }
  let h : Double = match root.height {
    @core.Fixed(v) => v
    _ => 844.0
  }
  sb.write_string(
    "let page = @decl.prototype(name=\"\{decl_escape(root.name)}\", width=\{num_text(w)}, height=\{num_text(h)})\n",
  )
  match root.layout {
    Some(l) => sb.write_string("page.set_layout(\{flex_text(l)})\n")
    None => ()
  }
  emit_children(self, sb, root.id, true)
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 解析：规范声明文本 → Prototype
// ---------------------------------------------------------------------------

///|
fn parse_params(
  args : String,
  line : Int,
) -> Result[Array[(String, String)], DeclParseError] {
  let out : Array[(String, String)] = Array::new()
  for raw in split_params(args).iter() {
    if !is_blank(raw) {
      match raw.find("=") {
        Some(eq) => {
          let key = trim_spaces(raw.substring(start=0, end=eq))
          let value = trim_spaces(raw.substring(start=eq + 1))
          out.push((key, value))
        }
        None => return Err({ line, message: "参数缺少 '='：\{raw}" })
      }
    }
  }
  Ok(out)
}

///|
fn opt_param(params : Array[(String, String)], key : String) -> String? {
  let mut found : String? = None
  for kv in params.iter() {
    let (k, v) = kv
    if k == key {
      found = Some(v)
    }
  }
  found
}

///|
fn str_val(v : String) -> String {
  let u : String = if v.length() >= 2 &&
    v.get_char(0) == Some('"') &&
    v.get_char(v.length() - 1) == Some('"') {
    v.substring(start=1, end=v.length() - 1)
  } else {
    v
  }
  unescape_decl(u)
}

///|
fn num_req(
  params : Array[(String, String)],
  key : String,
  line : Int,
) -> Result[Double, DeclParseError] {
  match opt_param(params, key) {
    Some(v) =>
      match parse_number(v) {
        Some(d) => Ok(d)
        None => Err({ line, message: "无法解析数值 \{v}" })
      }
    None => Err({ line, message: "缺少参数 \{key}" })
  }
}

///|
fn num_opt(
  params : Array[(String, String)],
  key : String,
  line : Int,
) -> Result[Double?, DeclParseError] {
  match opt_param(params, key) {
    Some(v) =>
      match parse_number(v) {
        Some(d) => Ok(Some(d))
        None => Err({ line, message: "无法解析数值 \{v}" })
      }
    None => Ok(None)
  }
}

///|
/// "@decl.fixed(44)" / "@decl.fill" / "@decl.hug" / 裸数字（容错视为定值）
fn size_val(v : String, line : Int) -> Result[@core.SizeSpec, DeclParseError] {
  let body : String = if has_prefix_str(v, DECL_MARKER) {
    v.substring(start=DECL_MARKER.length())
  } else {
    v
  }
  if body == "fill" {
    Ok(@core.Fill)
  } else if body == "hug" {
    Ok(@core.Hug)
  } else if has_prefix_str(body, "fixed(") && body.length() > 7 {
    match parse_number(body.substring(start=6, end=body.length() - 1)) {
      Some(d) => Ok(@core.Fixed(d))
      None => Err({ line, message: "无法解析 fixed 尺寸 \{body}" })
    }
  } else {
    match parse_number(body) {
      Some(d) => Ok(@core.Fixed(d))
      None => Err({ line, message: "无法解析尺寸规格 \{body}" })
    }
  }
}

///|
fn dir_val(v : String, line : Int) -> Result[@core.StackDir, DeclParseError] {
  let body = if has_prefix_str(v, DECL_MARKER) {
    v.substring(start=DECL_MARKER.length())
  } else {
    v
  }
  match body {
    "vertical" => Ok(@core.Vertical)
    "horizontal" => Ok(@core.Horizontal)
    other => Err({ line, message: "未知方向 \{other}" })
  }
}

///|
fn justify_val(v : String, line : Int) -> Result[@core.Justify, DeclParseError] {
  let body = if has_prefix_str(v, DECL_MARKER) {
    v.substring(start=DECL_MARKER.length())
  } else {
    v
  }
  match body {
    "justify_start" => Ok(@core.Start)
    "justify_center" => Ok(@core.Center)
    "justify_end" => Ok(@core.End)
    other => Err({ line, message: "未知对齐 \{other}" })
  }
}

///|
/// src 形如 "@decl.flex(direction=..., gap=..., padding=..., justify=...)"
fn parse_flex(
  src : String,
  line : Int,
) -> Result[@core.StackLayout, DeclParseError] {
  let body = if has_prefix_str(src, DECL_MARKER) {
    src.substring(start=DECL_MARKER.length())
  } else {
    src
  }
  if !(has_prefix_str(body, FLEX_MARKER) &&
    body.length() > FLEX_MARKER.length() + 1) {
    return Err({ line, message: "layout 须为 @decl.flex(...)" })
  }
  let args = body.substring(start=FLEX_MARKER.length(), end=body.length() - 1)
  match parse_params(args, line) {
    Err(e) => Err(e)
    Ok(params) => {
      let dir : @core.StackDir = match opt_param(params, "direction") {
        Some(v) =>
          match dir_val(v, line) {
            Ok(d) => d
            Err(e) => return Err(e)
          }
        None => @core.Vertical
      }
      let gap : Double = match num_opt(params, "gap", line) {
        Ok(Some(d)) => d
        Ok(None) => 0.0
        Err(e) => return Err(e)
      }
      let padding : Double = match num_opt(params, "padding", line) {
        Ok(Some(d)) => d
        Ok(None) => 0.0
        Err(e) => return Err(e)
      }
      let justify : @core.Justify = match opt_param(params, "justify") {
        Some(v) =>
          match justify_val(v, line) {
            Ok(j) => j
            Err(e) => return Err(e)
          }
        None => @core.Start
      }
      Ok(flex(direction=dir, gap~, padding~, justify~))
    }
  }
}

///|
fn with_xy(
  n : @core.Node,
  params : Array[(String, String)],
  line : Int,
) -> Result[@core.Node, DeclParseError] {
  let px = match opt_param(params, "x") {
    Some(v) =>
      match pos_val(v, line) {
        Ok(p) => Some(p)
        Err(err) => return Err(err)
      }
    None => None
  }
  let py = match opt_param(params, "y") {
    Some(v) =>
      match pos_val(v, line) {
        Ok(p) => Some(p)
        Err(err) => return Err(err)
      }
    None => None
  }
  match (px, py) {
    (Some(x), Some(y)) => add_layout({ ..n, x, y }, params, line)
    (Some(x), None) => add_layout({ ..n, x }, params, line)
    (None, Some(y)) => add_layout({ ..n, y }, params, line)
    (None, None) => add_layout(n, params, line)
  }
}

///|
/// 节点级 layout 解析：所有组件类型共用。
/// 此前只有 frame/兜底分支读取 layout，而序列化端对所有 kind 都写 layout=，
/// 于是 Rect/button/text/image 上的栈布局在 MBT 往返中被静默丢弃。
fn add_layout(
  n : @core.Node,
  params : Array[(String, String)],
  line : Int,
) -> Result[@core.Node, DeclParseError] {
  match opt_param(params, "layout") {
    None => Ok(n)
    Some(v) =>
      match parse_flex(v, line) {
        Ok(l) => Ok({ ..n, layout: Some(l) })
        Err(e) => Err(e)
      }
  }
}

///|
fn with_wh(
  n : @core.Node,
  params : Array[(String, String)],
  line : Int,
) -> Result[@core.Node, DeclParseError] {
  let w : @core.SizeSpec = match opt_param(params, "width") {
    Some(v) =>
      match size_val(v, line) {
        Ok(s) => s
        Err(err) => return Err(err)
      }
    None => return Err({ line, message: "缺少 width" })
  }
  let h : @core.SizeSpec = match opt_param(params, "height") {
    Some(v) =>
      match size_val(v, line) {
        Ok(s) => s
        Err(err) => return Err(err)
      }
    None => return Err({ line, message: "缺少 height" })
  }
  Ok({ ..n, width: w, height: h })
}

///|
fn require_id(
  params : Array[(String, String)],
  line : Int,
) -> Result[String, DeclParseError] {
  match opt_param(params, "id") {
    Some(v) => Ok(str_val(v))
    None => Err({ line, message: "缺少 id" })
  }
}

///|
/// 恢复 canonical MBT 中与具体组件无关的画布样式/约束字段。
fn apply_decl_style(
  node : @core.Node,
  params : Array[(String, String)],
  line : Int,
) -> Result[@core.Node, DeclParseError] {
  let mut cur = node
  match opt_param(params, "fill") {
    Some(v) => cur = { ..cur, style: { ..cur.style, fill: str_val(v) } }
    None => ()
  }
  match opt_param(params, "stroke") {
    Some(v) => cur = { ..cur, style: { ..cur.style, stroke: str_val(v) } }
    None => ()
  }
  match num_opt(params, "stroke_width", line) {
    Ok(Some(v)) => cur = { ..cur, style: { ..cur.style, stroke_width: v } }
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match opt_param(params, "text_align") {
    Some(v) => cur = { ..cur, style: { ..cur.style, text_align: str_val(v) } }
    None => ()
  }
  match opt_param(params, "font_style") {
    Some(v) => cur = { ..cur, style: { ..cur.style, font_style: str_val(v) } }
    None => ()
  }
  match opt_param(params, "stroke_dash") {
    Some(v) => cur = { ..cur, style: { ..cur.style, stroke_dash: str_val(v) } }
    None => ()
  }
  match opt_param(params, "visible") {
    Some(v) => cur = { ..cur, style: { ..cur.style, visible: str_val(v) != "false" } }
    None => ()
  }
  match opt_param(params, "overlay") {
    Some(v) => cur = { ..cur, style: { ..cur.style, overlay: str_val(v) == "true" } }
    None => ()
  }
  match num_opt(params, "radius", line) {
    Ok(Some(v)) => cur = { ..cur, style: { ..cur.style, corner_radius: v } }
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match num_opt(params, "opacity", line) {
    Ok(Some(v)) => cur = { ..cur, style: { ..cur.style, opacity: v } }
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match num_opt(params, "font_size", line) {
    Ok(Some(v)) => cur = { ..cur, style: { ..cur.style, font_size: v } }
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match opt_param(params, "text_color") {
    Some(v) => cur = { ..cur, style: { ..cur.style, text_color: str_val(v) } }
    None => ()
  }
  match opt_param(params, "shadow") {
    Some(v) => cur = { ..cur, style: { ..cur.style, shadow: str_val(v) } }
    None => ()
  }
  match num_opt(params, "rotate", line) {
    Ok(Some(v)) => cur = { ..cur, style: { ..cur.style, rotate: v } }
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match num_opt(params, "blur", line) {
    Ok(Some(v)) => cur = { ..cur, style: { ..cur.style, blur: v } }
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match opt_param(params, "blend") {
    Some(v) => cur = { ..cur, style: { ..cur.style, blend: str_val(v) } }
    None => ()
  }
  match num_opt(params, "line", line) {
    Ok(Some(v)) => cur = { ..cur, style: { ..cur.style, line_height: v } }
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match num_opt(params, "tracking", line) {
    Ok(Some(v)) => cur = { ..cur, style: { ..cur.style, tracking: v } }
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match opt_param(params, "flip") {
    Some(v) => cur = { ..cur, style: { ..cur.style, flip: str_val(v) } }
    None => ()
  }
  match opt_param(params, "constraint") {
    Some(v) => cur = { ..cur, constraint: str_val(v) }
    None => ()
  }
  Ok(cur)
}

///|
fn build_node(
  component : String,
  params : Array[(String, String)],
  line : Int,
) -> Result[@core.Node, DeclParseError] {
  let n : Result[@core.Node, DeclParseError] = match component {
    "generic_node" => {
      let id = match require_id(params, line) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let component_name = match opt_param(params, "component") {
        Some(v) => str_val(v)
        None => return Err({ line, message: "generic_node 缺少 component" })
      }
      let kind_name = match opt_param(params, "kind") {
        Some(v) => str_val(v)
        None => component_name
      }
      let width = match opt_param(params, "width") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(e) => return Err(e)
          }
        None => return Err({ line, message: "generic_node 缺少 width" })
      }
      let height = match opt_param(params, "height") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(e) => return Err(e)
          }
        None => return Err({ line, message: "generic_node 缺少 height" })
      }
      let x_pos = match opt_param(params, "x") {
        Some(v) =>
          match pos_val(v, line) {
            Ok(p) => p
            Err(e) => return Err(e)
          }
        None => @core.AlignStart(0.0)
      }
      let y_pos = match opt_param(params, "y") {
        Some(v) =>
          match pos_val(v, line) {
            Ok(p) => p
            Err(e) => return Err(e)
          }
        None => @core.AlignStart(0.0)
      }
      let text = match opt_param(params, "text") {
        Some(v) => str_val(v)
        None => ""
      }
      let fill = match opt_param(params, "fill") {
        Some(v) => str_val(v)
        None => "none"
      }
      let stroke = match opt_param(params, "stroke") {
        Some(v) => str_val(v)
        None => "none"
      }
      let stroke_width = match num_opt(params, "stroke_width", line) {
        Ok(Some(v)) => v
        Ok(None) => 0.0
        Err(e) => return Err(e)
      }
      let radius = match num_opt(params, "radius", line) {
        Ok(Some(v)) => v
        Ok(None) => 0.0
        Err(e) => return Err(e)
      }
      let opacity = match num_opt(params, "opacity", line) {
        Ok(Some(v)) => v
        Ok(None) => 1.0
        Err(e) => return Err(e)
      }
      let font_size = match num_opt(params, "font_size", line) {
        Ok(Some(v)) => v
        Ok(None) => 14.0
        Err(e) => return Err(e)
      }
      let text_color = match opt_param(params, "text_color") {
        Some(v) => str_val(v)
        None => "#111111"
      }
      let font_weight = match opt_param(params, "font_weight") {
        Some(v) => str_val(v)
        None => "normal"
      }
      let shadow = match opt_param(params, "shadow") {
        Some(v) => str_val(v)
        None => "none"
      }
      let rotate = match num_opt(params, "rotate", line) {
        Ok(Some(v)) => v
        Ok(None) => 0.0
        Err(e) => return Err(e)
      }
      let blur = match num_opt(params, "blur", line) {
        Ok(Some(v)) => v
        Ok(None) => 0.0
        Err(e) => return Err(e)
      }
      let blend = match opt_param(params, "blend") {
        Some(v) => str_val(v)
        None => "normal"
      }
      let line_height = match num_opt(params, "line_height", line) {
        Ok(Some(v)) => v
        Ok(None) => 1.5
        Err(e) => return Err(e)
      }
      let tracking = match num_opt(params, "tracking", line) {
        Ok(Some(v)) => v
        Ok(None) => 0.0
        Err(e) => return Err(e)
      }
      let flip = match opt_param(params, "flip") {
        Some(v) => str_val(v)
        None => "none"
      }
      let constraint = match opt_param(params, "constraint") {
        Some(v) => str_val(v)
        None => "lt"
      }
      let text_align = match opt_param(params, "text_align") {
        Some(v) => str_val(v)
        None => "left"
      }
      let font_style = match opt_param(params, "font_style") {
        Some(v) => str_val(v)
        None => "normal"
      }
      let stroke_dash = match opt_param(params, "stroke_dash") {
        Some(v) => str_val(v)
        None => "solid"
      }
      let visible = match opt_param(params, "visible") {
        Some(v) => str_val(v) != "false"
        None => true
      }
      let node_name = match opt_param(params, "name") {
        Some(v) => str_val(v)
        None => ""
      }
      let layout : @core.StackLayout? = match opt_param(params, "layout") {
        Some(v) =>
          match parse_flex(v, line) {
            Ok(value) => Some(value)
            Err(e) => return Err(e)
          }
        None => None
      }
      match
        apply_decl_style(
          generic_node(
            id~,
            component=component_name,
            width~,
            height~,
            kind=kind_name,
            x=@core.pos_offset_x(x_pos),
            y=@core.pos_offset_y(y_pos),
            text~,
            layout~,
            fill~,
            stroke~,
            stroke_width~,
            radius~,
            opacity~,
            font_size~,
            text_color~,
            font_weight~,
            shadow~,
            rotate~,
            blur~,
            blend~,
            line_height~,
            tracking~,
            flip~,
            constraint~,
            text_align~,
            font_style~,
            stroke_dash~,
            visible~,
            name=node_name,
          ),
          params,
          line,
        ) {
        Ok(node) => Ok({ ..node, x: x_pos, y: y_pos })
        Err(e) => Err(e)
      }
    }
    "text" => {
      let id : String = match require_id(params, line) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let content : String = match opt_param(params, "content") {
        Some(v) => str_val(v)
        None => ""
      }
      let mut cur = text(id~, content~)
      match num_opt(params, "size", line) {
        Ok(Some(d)) => cur = { ..cur, style: { ..cur.style, font_size: d } }
        Ok(None) => ()
        Err(err) => return Err(err)
      }
      match opt_param(params, "weight") {
        Some(v) =>
          cur = { ..cur, style: { ..cur.style, font_weight: str_val(v) } }
        None => ()
      }
      match opt_param(params, "color") {
        Some(v) =>
          cur = { ..cur, style: { ..cur.style, text_color: str_val(v) } }
        None => ()
      }
      with_xy(cur, params, line)
    }
    "text_input" => {
      let id : String = match require_id(params, line) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let placeholder : String = match opt_param(params, "placeholder") {
        Some(v) => str_val(v)
        None => ""
      }
      let w : @core.SizeSpec = match opt_param(params, "width") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => @core.Fill
      }
      let h : @core.SizeSpec = match opt_param(params, "height") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => @core.Fixed(44.0)
      }
      with_xy(text_input(id~, width=w, height=h, placeholder~), params, line)
    }
    "button" => {
      let id : String = match require_id(params, line) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let label : String = match opt_param(params, "label") {
        Some(v) => str_val(v)
        None => "按钮"
      }
      let w : @core.SizeSpec = match opt_param(params, "width") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => @core.Fill
      }
      let h : @core.SizeSpec = match opt_param(params, "height") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => @core.Fixed(48.0)
      }
      with_xy(button(id~, width=w, height=h, label~), params, line)
    }
    "rect" => {
      let id : String = match require_id(params, line) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let w : @core.SizeSpec = match opt_param(params, "width") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => @core.Fixed(100.0)
      }
      let h : @core.SizeSpec = match opt_param(params, "height") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => @core.Fixed(100.0)
      }
      let base = rect(id~, width=w, height=h)
      let f : @core.Node = match opt_param(params, "fill") {
        Some(v) => { ..base, style: { ..base.style, fill: str_val(v) } }
        None => base
      }
      let rf : @core.Node = match num_opt(params, "radius", line) {
        Ok(Some(d)) => { ..f, style: { ..f.style, corner_radius: d } }
        Ok(None) => f
        Err(err) => return Err(err)
      }
      let lb : @core.Node = match opt_param(params, "text") {
        Some(v) => { ..rf, text: str_val(v) }
        None => rf
      }
      with_xy(lb, params, line)
    }
    "image" => {
      let id : String = match require_id(params, line) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let w : @core.SizeSpec = match opt_param(params, "width") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => @core.Fixed(100.0)
      }
      let h : @core.SizeSpec = match opt_param(params, "height") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => @core.Fixed(100.0)
      }
      // text 承载图片 src（http/https/data URL）；序列化走 generic_node
      // 的 text= 字段，往返闭环
      let im = image(id~, width=w, height=h)
      let im2 = match opt_param(params, "text") {
        Some(v) => { ..im, text: str_val(v) }
        None => im
      }
      with_xy(im2, params, line)
    }
    "group" => {
      let id : String = match require_id(params, line) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      with_xy(group(id~), params, line)
    }
    "frame" => {
      let id : String = match require_id(params, line) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let w : @core.SizeSpec = match opt_param(params, "width") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => return Err({ line, message: "frame 缺少 width" })
      }
      let h : @core.SizeSpec = match opt_param(params, "height") {
        Some(v) =>
          match size_val(v, line) {
            Ok(s) => s
            Err(err) => return Err(err)
          }
        None => return Err({ line, message: "frame 缺少 height" })
      }
      // layout 由 with_xy → add_layout 统一解析（覆盖所有组件类型）
      let base = frame(id~, width=w, height=h)
      let fd : @core.Node = match opt_param(params, "fill") {
        Some(v) => { ..base, style: { ..base.style, fill: str_val(v) } }
        None => base
      }
      with_xy(fd, params, line)
    }
    other => Err({ line, message: "未知组件 \{other}" })
  }
  match n {
    Ok(node) => apply_decl_style(node, params, line)
    Err(error) => Err(error)
  }
}

///|
/// 解析 "…node=@decl.<comp>(<args>…)" 段并加入原型
fn apply_call(
  page : Prototype,
  call_src : String,
  pid_opt : String?,
  line : Int,
) -> Result[Unit, DeclParseError] {
  if !has_prefix_str(call_src, DECL_MARKER) {
    return Err({
      line,
      message: "节点调用须以 @decl. 开头：\{call_src}",
    })
  }
  let body = call_src.substring(start=DECL_MARKER.length())
  let lp : Int = match body.find("(") {
    Some(i) => i
    None => return Err({ line, message: "组件调用缺少括号" })
  }
  if body.length() < lp + 3 {
    return Err({ line, message: "组件调用参数不完整" })
  }
  let component = body.substring(start=0, end=lp)
  let args = body.substring(start=lp + 1, end=body.length() - 1)
  if is_blank(component) {
    return Err({ line, message: "组件名缺失" })
  }
  match parse_params(args, line) {
    Err(e) => Err(e)
    Ok(params) =>
      match build_node(component, params, line) {
        Err(e) => Err(e)
        Ok(n) =>
          if page.index.contains(n.id) {
            Err({ line, message: "duplicate_id: \{n.id}" })
          } else {
            match pid_opt {
              Some(pid) =>
                if page.index.contains(pid) {
                  p_add(page, pid, n)
                  Ok(())
                } else {
                  Err({ line, message: "unknown_parent: \{pid}" })
                }
              None => {
                p_add(page, "root", n)
                Ok(())
              }
            }
          }
      }
  }
}

///|
fn p_add(page : Prototype, parent_id : String, n : @core.Node) -> Unit {
  page.add_to(parent_id~, node=n)
}

///|
/// 声明文本 → Prototype（含行级错误定位）
pub fn parse_decl(text : String) -> Result[Prototype, DeclParseError] {
  let lines = lines_of(text)
  let mut page : Prototype? = None
  let mut line_no = 0
  for raw in lines.iter() {
    line_no = line_no + 1
    let line = trim_spaces(raw)
    if line.length() > 0 {
      if has_prefix_str(line, PROTO_PREFIX) {
        let args = line.substring(
          start=PROTO_PREFIX.length(),
          end=line.length() - 1,
        )
        match parse_params(args, line_no) {
          Err(e) => return Err(e)
          Ok(params) => {
            let name : String = match opt_param(params, "name") {
              Some(v) => str_val(v)
              None => "原型"
            }
            let width : Double = match num_req(params, "width", line_no) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            let height : Double = match num_req(params, "height", line_no) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            page = Some(prototype(name~, width~, height~))
          }
        }
      } else if has_prefix_str(line, LAYOUT_PREFIX) {
        let inner = line.substring(
          start=LAYOUT_PREFIX.length(),
          end=line.length() - 1,
        )
        match page {
          None =>
            return Err({
              line: line_no,
              message: "set_layout 出现在 prototype 之前",
            })
          Some(p) =>
            match parse_flex(inner, line_no) {
              Ok(l) => p.set_layout(l)
              Err(e) => return Err(e)
            }
        }
      } else if has_prefix_str(line, ADD_TO_PREFIX) {
        // 行形如：page.add_to(parent_id="card", node=@decl.rect(...))
        let inner = line.substring(start=ADD_TO_PREFIX.length())
        let pid : String = match inner.find("\"") {
          Some(q) => inner.substring(start=0, end=q)
          None =>
            return Err({ line: line_no, message: "add_to 缺少 parent_id 值" })
        }
        // 提取 node=@decl.<call>)（剥掉 add_to 的收尾括号）
        match inner.find(NODE_MARKER) {
          None =>
            return Err({
              line: line_no,
              message: "add_to 缺少 node=@decl.<组件> 调用",
            })
          Some(i) => {
            // call 从 "@decl." 起（NODE_MARKER 含 node= 前缀）
            let call = inner.substring(
              start=i + NODE_MARKER.length() - DECL_MARKER.length(),
              end=inner.length() - 1,
            )
            match page {
              None =>
                return Err({
                  line: line_no,
                  message: "节点出现在 prototype 之前",
                })
              Some(p) =>
                match apply_call(p, call, Some(pid), line_no) {
                  Ok(_) => ()
                  Err(e) => return Err(e)
                }
            }
          }
        }
      } else if has_prefix_str(line, ADD_PREFIX) {
        let call = line.substring(
          start=ADD_PREFIX.length(),
          end=line.length() - 1,
        )
        match page {
          None =>
            return Err({
              line: line_no,
              message: "节点出现在 prototype 之前",
            })
          Some(p) =>
            match apply_call(p, call, None, line_no) {
              Ok(_) => ()
              Err(e) => return Err(e)
            }
        }
      } else {
        return Err({
          line: line_no,
          message: "无法识别的声明行：\{line}",
        })
      }
    }
  }
  match page {
    None =>
      Err({
        line: lines.length(),
        message: "缺少 let page = @decl.prototype(...) 行",
      })
    Some(p) => Ok(p)
  }
}
