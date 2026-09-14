/// 渲染桥接层：从文档模型生成 SVG。
/// 渲染层不承担正确性责任——能走到这里的文档都已通过（或被人类路线明确
/// 接受为）验证层的谓词检查。
///
/// v2 现代视觉：elevation 阴影令牌、系统字体栈、多行文本、浅底衬托白卡。

///|
/// 文档 → SVG 字符串（根矩形即画布尺寸，浅底）
pub fn render_svg(doc : Document) -> String {
  let layout = solve(doc)
  let root_rect : Rect = match layout.rect_of(doc.root_id) {
    Some(r) => r
    None => Rect::new(0.0, 0.0, 390.0, 844.0)
  }
  let sb = StringBuilder::new()
  sb.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{root_rect.width}\" height=\"\{root_rect.height}\" viewBox=\"0 0 \{root_rect.width} \{root_rect.height}\">",
  )
  // 现代视觉基座：字体栈 + elevation 阴影令牌
  sb.write_string(
    "<style>text{font-family:-apple-system,'SF Pro Text','PingFang SC','Segoe UI',Roboto,sans-serif}</style>",
  )
  // Paint v2：渐变 defs（linear:#a:#b@deg / radial:#a:#b）
  let defs = collect_gradients(doc)
  if defs != "" {
    sb.write_string(defs)
  }
  sb.write_string(
    "<defs><filter id=\"e1\" x=\"-30%\" y=\"-30%\" width=\"160%\" height=\"160%\"><feDropShadow dx=\"0\" dy=\"1\" stdDeviation=\"2\" flood-opacity=\"0.07\"/></filter><filter id=\"e2\" x=\"-30%\" y=\"-30%\" width=\"160%\" height=\"160%\"><feDropShadow dx=\"0\" dy=\"4\" stdDeviation=\"10\" flood-opacity=\"0.10\"/></filter><filter id=\"e3\" x=\"-30%\" y=\"-30%\" width=\"160%\" height=\"170%\"><feDropShadow dx=\"0\" dy=\"14\" stdDeviation=\"28\" flood-opacity=\"0.16\"/></filter></defs>",
  )
  sb.write_string(
    "<rect x=\"0\" y=\"0\" width=\"\{root_rect.width}\" height=\"\{root_rect.height}\" fill=\"#F6F7F9\" pointer-events=\"none\"/>",
  )
  // SVG viewBox 自带裁剪（root rect 与 viewBox 同尺寸），不再用 clipPath 包裹：
  // WebKit 对 clip-path 组内元素的 hit-test 会整体失效，原型交互点击会穿透。
  render_node(sb, doc, doc.root_id, layout)
  sb.write_string("</svg>")
  sb.to_string()
}

///|
fn render_node(
  sb : StringBuilder,
  doc : Document,
  id : String,
  layout : SolvedLayout,
) -> Unit {
  match doc.nodes.get(id) {
    None => ()
    Some(n) =>
      match layout.rect_of(id) {
        None => ()
        Some(r) => {
          // 每个节点包一层 <g id>：编辑器据此把 DOM 元素与场景图节点关联
          sb.write_string("<g id=\"n_\{id}\" data-kind=\"\{svg_kind_of(n)}\">")
          match n.kind {
            Text => render_text_node(sb, n, r)
            Image => {
              // 图片占位：浅灰底 + 山形/太阳图标 + 细边框，任何尺寸下可辨识
              sb.write_string(
                "<rect x=\"\{r.x}\" y=\"\{r.y}\" width=\"\{r.width}\" height=\"\{r.height}\" rx=\"\{n.style.corner_radius}\" fill=\"#EEF0F4\" stroke=\"#D5DAE3\" stroke-width=\"1\"/>",
              )
              let ic = r.width / 6.0
              if ic > 2.0 {
                let cx = r.x + r.width / 2.0
                let cy = r.y + r.height / 2.0
                let iw = ic * 2.4
                let ih = ic * 1.5
                sb.write_string(
                  "<path d=\"M\{cx - iw / 2.0} \{cy + ih / 2.0 - ih * 0.2} L\{cx - iw * 0.22} \{cy - ih / 2.0 + ih * 0.15} L\{cx + iw * 0.05} \{cy + ih * 0.1} L\{cx + iw * 0.35} \{cy - ih * 0.35} L\{cx + iw / 2.0} \{cy + ih / 2.0 - ih * 0.2}\" fill=\"#C3CAD6\"/>",
                )
                sb.write_string(
                  "<circle cx=\"\{cx + iw * 0.28}\" cy=\"\{cy - ih * 0.42}\" r=\"\{ic * 0.32}\" fill=\"#C3CAD6\"/>",
                )
              }
            }
            _ => {
              // Frame / Group / Rect
              sb.write_string(
                "<rect x=\"\{r.x}\" y=\"\{r.y}\" width=\"\{r.width}\" height=\"\{r.height}\" rx=\"\{n.style.corner_radius}\" fill=\"\{paint_ref(n.style.fill, n.id)}\"",
              )
              if n.style.stroke != "none" {
                sb.write_string(
                  " stroke=\"\{n.style.stroke}\" stroke-width=\"1\"",
                )
              } else if n.style.fill == "none" && n.text == "" {
                // 无填充无文字的容器：细虚线边界，避免"幽灵组件"融进背景
                sb.write_string(
                  " stroke=\"#C9CFDA\" stroke-width=\"1\" stroke-dasharray=\"4 3\"",
                )
              }
              if n.style.opacity != 1.0 {
                sb.write_string(" opacity=\"\{n.style.opacity}\"")
              }
              if n.style.shadow != "none" {
                sb.write_string(" filter=\"url(#\{n.style.shadow})\"")
              }
              if n.style.blur > 0.0 {
                sb.write_string(" filter=\"url(#blur_\{svg_id_tag(n.id)})\"")
              }
              if n.style.rotate != 0.0 {
                let cx = r.x + r.width / 2.0
                let cy = r.y + r.height / 2.0
                sb.write_string(
                  " transform=\"rotate(\{n.style.rotate} \{cx} \{cy})\"",
                )
              }
              if n.style.flip != "none" {
                let cx = r.x + r.width / 2.0
                let cy = r.y + r.height / 2.0
                let m = match n.style.flip {
                  "h" => "-1,1"
                  "v" => "1,-1"
                  _ => "-1,-1"
                }
                sb.write_string(
                  " transform=\"translate(\{cx} \{cy}) scale(\{m}) translate(\{-cx} \{-cy})\"",
                )
              }
              sb.write_string("/>")
              // 带文字的形状（按钮 / 输入框占位符）：水平垂直居中
              if n.text != "" {
                let baseline = r.y + (r.height + n.style.font_size * 0.7) / 2.0
                sb.write_string(
                  "<text x=\"\{r.x + r.width / 2.0}\" y=\"\{baseline}\" text-anchor=\"middle\" font-size=\"\{n.style.font_size}\" font-weight=\"\{n.style.font_weight}\" fill=\"\{n.style.text_color}\">\{xml_escape(n.text)}</text>",
                )
              }
            }
          }
          for cid in n.children.iter() {
            render_node(sb, doc, cid, layout)
          }
          sb.write_string("</g>")
        }
      }
  }
}

///|
/// 文本节点：支持 \n 多行、自定义行高、字距
fn render_text_node(sb : StringBuilder, n : Node, r : Rect) -> Unit {
  let lines = split_lines(n.text)
  let lh = n.style.font_size * n.style.line_height
  let first_baseline = r.y + n.style.font_size * 1.0
  sb.write_string(
    "<text x=\"\{r.x}\" y=\"\{first_baseline}\" font-size=\"\{n.style.font_size}\" font-weight=\"\{n.style.font_weight}\" letter-spacing=\"\{n.style.tracking * n.style.font_size}\" fill=\"\{paint_ref_t(n.style.text_color, n.id)}\"",
  )
  if lines.length() == 1 {
    sb.write_string(">\{xml_escape(lines[0])}</text>")
  } else {
    sb.write_string(">")
    for i in 0..<lines.length() {
      let dy = if i == 0 { 0.0 } else { lh }
      sb.write_string(
        "<tspan x=\"\{r.x}\" dy=\"\{dy}\">\{xml_escape(lines[i])}</tspan>",
      )
    }
    sb.write_string("</text>")
  }
}

///|
/// 按 \n 拆行（无换行返回单元素数组）
fn split_lines(s : String) -> Array[String] {
  let out : Array[String] = []
  let cur = StringBuilder::new()
  for c in s.iter() {
    if c == '\n' {
      out.push(cur.to_string())
      cur.reset()
    } else {
      cur.write_char(c)
    }
  }
  out.push(cur.to_string())
  out
}

///|
fn svg_kind_of(n : Node) -> String {
  match n.kind {
    Frame => "frame"
    Group => "group"
    Rect => "rect"
    Text => "text"
    Image => "image"
  }
}

///|
/// Paint DSL 引用："#hex" 原样；"linear:#a:#b@deg"/"radial:#a:#b" → url(#g_tag)
fn paint_ref(fill : String, node_id : String) -> String {
  if has_prefix(fill, "linear:") || has_prefix(fill, "radial:") {
    return "url(#g_\{svg_id_tag(node_id)})"
  }
  fill
}

///|
/// 文字色渐变引用（def 以 _t 后缀注册）
fn paint_ref_t(color : String, node_id : String) -> String {
  if has_prefix(color, "linear:") || has_prefix(color, "radial:") {
    return "url(#g_\{svg_id_tag(node_id)}_t)"
  }
  color
}

///|
/// 节点 id → SVG id 安全 tag
fn svg_id_tag(id : String) -> String {
  let sb = StringBuilder::new()
  for c in id.iter() {
    let code = c.to_int()
    if (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) {
      sb.write_char(c)
    } else {
      sb.write_char('_')
    }
  }
  sb.to_string()
}

///|
/// 遍历文档收集全部渐变，生成 <defs> 段
fn collect_gradients(doc : Document) -> String {
  let sb = StringBuilder::new()
  for id in doc.nodes.keys() {
    match doc.get(id) {
      None => ()
      Some(n) => {
        let g = gradient_def(n.style.fill, id)
        if g != "" {
          sb.write_string(g)
        }
        // 文字色也可能是渐变
        let tg = gradient_def(n.style.text_color, id + "_t")
        if tg != "" {
          sb.write_string(tg)
        }
      }
    }
  }
  // blur 滤镜 defs
  for id in doc.nodes.keys() {
    match doc.get(id) {
      None => ()
      Some(n) =>
        if n.style.blur > 0.0 {
          sb.write_string(
            "<filter id=\"blur_\{svg_id_tag(id)}\" x=\"-30%\" y=\"-30%\" width=\"160%\" height=\"160%\"><feGaussianBlur stdDeviation=\"\{n.style.blur}\"/></filter>",
          )
        }
    }
  }
  let inner = sb.to_string()
  if inner == "" {
    ""
  } else {
    "<defs>\{inner}</defs>"
  }
}

///|
/// 单个 Paint DSL → 渐变 def；非渐变返回 ""
fn has_prefix(s : String, pre : String) -> Bool {
  if s.length() < pre.length() {
    return false
  }
  s.substring(start=0, end=pre.length()) == pre
}

///|
fn gradient_def(paint : String, id : String) -> String {
  if has_prefix(paint, "linear:") {
    let body = paint.substring(start=7, end=paint.length())
    let (c1, c2, deg) = parse_two_colors_angle(body)
    let tag = "g_\{svg_id_tag(id)}"
    // 角度 → (x1,y1,x2,y2)：0°=→ 90°=↓
    let rad = deg * 3.14159265 / 180.0
    let x2 = (0.5 + 0.5 * rad_cos(rad)).to_string()
    let y2 = (0.5 + 0.5 * rad_sin(rad)).to_string()
    let x1 = (0.5 - 0.5 * rad_cos(rad)).to_string()
    let y1 = (0.5 - 0.5 * rad_sin(rad)).to_string()
    return "<linearGradient id=\"\{tag}\" x1=\"\{x1}\" y1=\"\{y1}\" x2=\"\{x2}\" y2=\"\{y2}\"><stop offset=\"0\" stop-color=\"\{c1}\"/><stop offset=\"1\" stop-color=\"\{c2}\"/></linearGradient>"
  }
  if has_prefix(paint, "radial:") {
    let body = paint.substring(start=7, end=paint.length())
    let (c1, c2, _deg) = parse_two_colors_angle(body)
    let tag = "g_\{svg_id_tag(id)}"
    return "<radialGradient id=\"\{tag}\"><stop offset=\"0\" stop-color=\"\{c1}\"/><stop offset=\"1\" stop-color=\"\{c2}\"/></radialGradient>"
  }
  ""
}

///|
/// "a@45" / "a" / "a:b@45" → (c1, c2, deg)
fn parse_two_colors_angle(body : String) -> (String, String, Double) {
  // 先拆角度
  let mut color_part = body
  let mut deg = 90.0
  let at = index_of_at(body)
  if at >= 0 {
    color_part = body.substring(start=0, end=at)
    deg = parse_deg(body.substring(start=at + 1, end=body.length()))
  }
  let parts = split_char(color_part, ':')
  let c1 = if parts.length() > 0 { parts[0] } else { "#cccccc" }
  let c2 = if parts.length() > 1 { parts[1] } else { c1 }
  (c1, c2, deg)
}

///|
/// 找 @ 首次出现位置，未找到 -1
fn index_of_at(s : String) -> Int {
  let mut i = 0
  for c in s.iter() {
    if c == '@' {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn parse_deg(s : String) -> Double {
  let mut v = 0.0
  for c in s.iter() {
    let code = c.to_int()
    if code >= 48 && code <= 57 {
      v = v * 10.0 + (code - 48).to_double()
    }
  }
  v
}

///|
fn split_char(s : String, sep : Char) -> Array[String] {
  let out : Array[String] = []
  let cur = StringBuilder::new()
  for c in s.iter() {
    if c == sep {
      out.push(cur.to_string())
      cur.reset()
    } else {
      cur.write_char(c)
    }
  }
  out.push(cur.to_string())
  out
}

///|
fn rad_cos(r : Double) -> Double {
  // cos 的泰勒近似（-π..π 精度足够渲染视觉）
  let x = wrap_angle(r)
  let x2 = x * x
  1.0 - x2 / 2.0 + x2 * x2 / 24.0 - x2 * x2 * x2 / 720.0
}

///|
fn rad_sin(r : Double) -> Double {
  let x = wrap_angle(r)
  let x2 = x * x
  x - x * x2 / 6.0 + x * x2 * x2 / 120.0
}

///|
fn wrap_angle(r : Double) -> Double {
  // 归一到 -π..π
  let pi = 3.14159265
  let mut x = r
  while x > pi {
    x = x - 2.0 * pi
  }
  while x < -pi {
    x = x + 2.0 * pi
  }
  x
}

///|
fn xml_escape(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}
