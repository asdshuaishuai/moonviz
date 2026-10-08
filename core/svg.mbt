/// 渲染桥接层：从文档模型生成 SVG。
/// 渲染层不承担正确性责任——能走到这里的文档都已通过（或被人类路线明确
/// 接受为）验证层的谓词检查。
///
/// v2 现代视觉：elevation 阴影令牌、系统字体栈、多行文本、浅底衬托白卡。

///|
/// 文档 → SVG 字符串（根矩形即画布尺寸，浅底）
///
/// surface 为画布底色令牌值：主题切换后由 Project 侧传入当前主题的
/// surface（如 nord 的 #2E3440）；默认浅色 #F6F7F9 保持既有文档兼容。
pub fn render_svg(
  doc : Document,
  surface? : String = "#F6F7F9",
  frame? : String = "#C9CFDA",
  data? : DataValue = DNull,
) -> String {
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
    "<defs><filter id=\"e1\" x=\"-30%\" y=\"-30%\" width=\"160%\" height=\"160%\"><feDropShadow dx=\"0\" dy=\"1\" stdDeviation=\"2\" flood-opacity=\"0.07\"/></filter><filter id=\"e2\" x=\"-30%\" y=\"-30%\" width=\"160%\" height=\"160%\"><feDropShadow dx=\"0\" dy=\"4\" stdDeviation=\"10\" flood-opacity=\"0.10\"/></filter><filter id=\"e3\" x=\"-30%\" y=\"-30%\" width=\"160%\" height=\"170%\"><feDropShadow dx=\"0\" dy=\"14\" stdDeviation=\"28\" flood-opacity=\"0.16\"/></filter><filter id=\"e4\" x=\"-40%\" y=\"-40%\" width=\"180%\" height=\"180%\"><feDropShadow dx=\"0\" dy=\"2\" stdDeviation=\"6\" flood-color=\"#4B6BFB\" flood-opacity=\"0.35\"/></filter><filter id=\"e5\" x=\"-40%\" y=\"-40%\" width=\"180%\" height=\"180%\"><feDropShadow dx=\"0\" dy=\"10\" stdDeviation=\"24\" flood-opacity=\"0.30\"/></filter></defs>",
  )
  sb.write_string(
    "<rect x=\"0\" y=\"0\" width=\"\{root_rect.width}\" height=\"\{root_rect.height}\" fill=\"\{surface}\" pointer-events=\"none\"/>",
  )
  // SVG viewBox 自带裁剪（root rect 与 viewBox 同尺寸），不再用 clipPath 包裹：
  // WebKit 对 clip-path 组内元素的 hit-test 会整体失效，原型交互点击会穿透。
  render_node(sb, doc, doc.root_id, layout, surface~, frame~, data~)
  sb.write_string("</svg>")
  sb.to_string()
}

///|
fn render_node(
  sb : StringBuilder,
  doc : Document,
  id : String,
  layout : SolvedLayout,
  surface~ : String,
  frame~ : String,
  data~ : DataValue,
) -> Unit {
  match doc.nodes.get(id) {
    None => ()
    // 隐藏节点：整棵子树不参与渲染（文档中仍保留，可随时 visible=true 恢复）
    Some(n) if !n.style.visible => ()
    Some(n) =>
      match layout.rect_of(id) {
        None => ()
        Some(r) => {
          // 每个节点包一层 <g id>：编辑器据此把 DOM 元素与场景图节点关联
          sb.write_string("<g id=\"n_\{id}\" data-kind=\"\{svg_kind_of(n)}\">")
          match n.kind {
            Text => render_text_node(sb, n, r, data~)
            Image => {
              // text 承载 src：http(s)/data URL → 真 <image>（圆角裁剪）；
              // 空/非 URL → 占位渲染（浅灰底 + 山形/太阳图标）
              let src = xml_escape(n.text)
              if has_url_prefix(src) {
                if n.style.corner_radius > 0.0 {
                  sb.write_string(
                    "<clipPath id=\"img_\{svg_id_tag(n.id)}\"><rect x=\"\{r.x}\" y=\"\{r.y}\" width=\"\{r.width}\" height=\"\{r.height}\" rx=\"\{n.style.corner_radius}\"/></clipPath>",
                  )
                  sb.write_string(
                    "<image href=\"\{src}\" x=\"\{r.x}\" y=\"\{r.y}\" width=\"\{r.width}\" height=\"\{r.height}\" preserveAspectRatio=\"xMidYMid slice\" clip-path=\"url(#img_\{svg_id_tag(n.id)})\"/>",
                  )
                } else {
                  sb.write_string(
                    "<image href=\"\{src}\" x=\"\{r.x}\" y=\"\{r.y}\" width=\"\{r.width}\" height=\"\{r.height}\" preserveAspectRatio=\"xMidYMid slice\"/>",
                  )
                }
              } else {
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
            }
            _ => {
              // Frame / Group / Rect
              sb.write_string(
                "<rect x=\"\{r.x}\" y=\"\{r.y}\" width=\"\{r.width}\" height=\"\{r.height}\" rx=\"\{n.style.corner_radius}\" fill=\"\{paint_ref(n.style.fill, n.id)}\"",
              )
              if n.style.stroke != "none" {
                let sw = if n.style.stroke_width > 0.0 {
                  n.style.stroke_width
                } else {
                  1.0
                }
                sb.write_string(" stroke=\"\{n.style.stroke}\" stroke-width=\"\{sw}\"")
                match dash_array(n.style.stroke_dash) {
                  Some(da) => sb.write_string(" stroke-dasharray=\"\{da}\"")
                  None => ()
                }
              } else if n.style.fill == "none" && n.text == "" {
                // 无填充无文字的容器：细虚线边界，避免"幽灵组件"融进背景
                sb.write_string(
                  " stroke=\"\{frame}\" stroke-width=\"1\" stroke-dasharray=\"4 3\"",
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
              // 图标在 rect 闭合后作为兄弟元素输出——写进 <rect> 起始标签内会产出非法 XML
              if n.style.icon != "" {
                match icon_path(n.style.icon) {
                  Some(d) => {
                    let short = if r.width < r.height { r.width } else { r.height }
                    if short > 0.0 {
                      let s2 = short * 0.55 / 24.0
                      let ix = r.x + (r.width - 24.0 * s2) / 2.0
                      let iy = r.y + (r.height - 24.0 * s2) / 2.0
                      sb.write_string(
                        "<g transform=\"translate(\{ix},\{iy}) scale(\{s2})\" fill=\"none\" stroke=\"\{paint_ref_t(n.style.text_color, n.id)}\" stroke-width=\"\{2.0 / s2}\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"\{d}\"/></g>",
                      )
                    }
                  }
                  None => ()
                }
              }
              // 带文字的形状（按钮 / 输入框占位符）：默认水平垂直居中，
              // align=left/right 时改为左/右对齐到内边距；font_fit 同样生效
              if n.text != "" {
                // Smart UX M-S1：rect 载字（按钮/输入框标签）同样解析 {{绑定}}
                let text2 = resolve_bindings(n.text, data)
                let fs2 = if n.style.font_fit == "auto" || n.style.font_fit == "shrink" {
                  fit_font_size(
                    text2,
                    n.style.font_size,
                    r.width - 24.0,
                    r.height,
                    n.style.line_height,
                    n.style.font_fit,
                  )
                } else {
                  n.style.font_size
                }
                let baseline = r.y + (r.height + fs2 * 0.7) / 2.0
                let pad = 12.0
                let (tx, anchor) = match n.style.text_align {
                  "left" => (r.x + pad, " start")
                  "right" => (r.x + r.width - pad, " end")
                  _ => (r.x + r.width / 2.0, " middle")
                }
                sb.write_string(
                  "<text x=\"\{tx}\" y=\"\{baseline}\" text-anchor=\"\{anchor}\" font-size=\"\{fs2}\" font-weight=\"\{font_weight_value(n.style.font_weight)}\"",
                )
                if n.style.font_style == "italic" {
                  sb.write_string(" font-style=\"italic\"")
                }
                sb.write_string(
                  " fill=\"\{n.style.text_color}\">\{xml_escape(text2)}</text>",
                )
              }
            }
          }
          for cid in n.children.iter() {
            render_node(sb, doc, cid, layout, surface~, frame~, data~)
          }
          sb.write_string("</g>")
        }
      }
  }
}

///|
/// 文本节点：支持 \n 多行、自定义行高、字距
///|
/// 字重名 → 数值（SVG font-weight 用数值才能拿到真实字重渲染；
/// "normal"/数字串原样透传）。1.0 R1：字重真实映射。
fn font_weight_value(w : String) -> String {
  match w {
    "light" => "300"
    "normal" | "regular" => "400"
    "medium" => "500"
    "semibold" => "600"
    "bold" => "700"
    "black" => "900"
    _ => w
  }
}

///|
///|
/// 1.0 R1 自适应字号：font_fit="auto" 双向（溢出等比缩 / 单行留白放大，2 倍
/// preferred 封顶）或 "shrink" 只缩不涨。单次比例计算无循环，下限 8px，永不崩溃。
fn fit_font_size(
  text : String,
  pref : Double,
  width : Double,
  height : Double,
  line_h : Double,
  mode : String,
) -> Double {
  if width <= 0.0 || height <= 0.0 || pref <= 0.0 || text.length() == 0 {
    return pref
  }
  let min_fit = 8.0
  let lines = wrap_text_lines(text, pref, width)
  let needed = lines.length().to_double() * pref * line_h
  if needed > height {
    // 溢出 → 等比缩（换行数按小字号只会更少，实际渲染只会更紧凑，不会回溢）
    let f = pref * height / needed
    if f < min_fit {
      return min_fit
    }
    return f
  }
  if mode == "auto" && lines.length() == 1 {
    // 单行文本才有"涨"的价值（标题填满 hero 槽位）；多行涨会扰动断行
    let by_h = height / line_h
    let by_w = width / text_em_width(text)
    let mut f = if by_h < by_w { by_h } else { by_w }
    let cap = pref * 2.0
    if f > cap {
      f = cap
    }
    if f > pref {
      return f
    }
  }
  pref
}

///|
fn render_text_node(
  sb : StringBuilder,
  n : Node,
  r : Rect,
  data~ : DataValue,
) -> Unit {
  // Smart UX M-S1：{{绑定}} 在测量/换行之前解析——fit 与换行都基于显示文本
  let text = resolve_bindings(n.text, data)
  // 1.0 R1：自适应字号（font_fit 开启时）+ 宽度感知换行
  let fs = if n.style.font_fit == "auto" || n.style.font_fit == "shrink" {
    fit_font_size(
      text,
      n.style.font_size,
      r.width,
      r.height,
      n.style.line_height,
      n.style.font_fit,
    )
  } else {
    n.style.font_size
  }
  let lines = wrap_text_lines(text, fs, r.width)
  let lh = fs * n.style.line_height
  // 单行文本在高于字号的矩形内垂直居中（按钮/输入框标签的标准形态，
  // 修 login-demo「按钮文字贴顶」证据）；多行保持顶部排版流
  let single_line = lines.length() == 1
  let first_baseline = if single_line && r.height >= fs * 1.4 {
    r.y + (r.height + fs * 0.72) / 2.0
  } else {
    r.y + fs * 1.0
  }
  // 水平对齐：left（默认，x 起点）/ center / right（x 终点 + text-anchor）
  let (tx, anchor) = match n.style.text_align {
    "center" => (r.x + r.width / 2.0, " text-anchor=\"middle\"")
    "right" => (r.x + r.width, " text-anchor=\"end\"")
    _ => (r.x, "")
  }
  sb.write_string(
    "<text x=\"\{tx}\" y=\"\{first_baseline}\" font-size=\"\{fs}\" font-weight=\"\{font_weight_value(n.style.font_weight)}\" letter-spacing=\"\{n.style.tracking * fs}\" fill=\"\{paint_ref_t(n.style.text_color, n.id)}\"",
  )
  if anchor != "" {
    sb.write_string(anchor)
  }
  if n.style.font_style == "italic" {
    sb.write_string(" font-style=\"italic\"")
  }
  if n.style.opacity != 1.0 {
    sb.write_string(" opacity=\"\{n.style.opacity}\"")
  }
  if lines.length() == 1 {
    sb.write_string(">\{xml_escape(lines[0])}</text>")
  } else {
    sb.write_string(">")
    for i in 0..<lines.length() {
      let dy = if i == 0 { 0.0 } else { lh }
      sb.write_string(
        "<tspan x=\"\{tx}\" dy=\"\{dy}\">\{xml_escape(lines[i])}</tspan>",
      )
    }
    sb.write_string("</text>")
  }
}

///|
/// 描边线型 → SVG stroke-dasharray 值；solid 返回 None（不输出该属性）
fn dash_array(dash : String) -> String? {
  match dash {
    "dashed" => Some("6 4")
    "dotted" => Some("1.5 3")
    _ => None
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
/// 单字符宽度估算（em 比例，乘以 font_size 得 px）
/// CJK ≈ 1.0em、大写拉丁 ≈ 0.65em、小写 ≈ 0.52em、数字 ≈ 0.55em、空格 ≈ 0.28em
fn char_em_width(c : Char) -> Double {
  let code = c.to_int()
  if code >= 0x4E00 && code <= 0x9FFF { 1.0
  } else if code >= 0x3000 && code <= 0x303F { 1.0
  } else if code >= 0xFF00 && code <= 0xFFEF { 1.0
  } else if code >= 65 && code <= 90 { 0.65
  } else if code >= 97 && code <= 122 { 0.52
  } else if code >= 48 && code <= 57 { 0.55
  } else if code == 32 { 0.28
  } else { 0.5 }
}

///|
/// 估算字符串宽度（em 单位，乘以 font_size 得 px）
fn text_em_width(s : String) -> Double {
  let mut w = 0.0
  for c in s.iter() { w = w + char_em_width(c) }
  w
}

///|
/// 宽度感知文本换行：按空格分词逐词贪心（Latin 整词断行）；
/// 超长词（含无空格的 CJK 整段）按字符硬拆。行内不保留首尾空格。
fn wrap_line_at_width(line : String, max_em : Double) -> Array[String] {
  if text_em_width(line) <= max_em { return [line] }
  let out : Array[String] = []
  let cur = StringBuilder::new()
  let mut cur_w = 0.0
  let word = StringBuilder::new()
  let mut word_w = 0.0
  for c in line.iter() {
    if c == ' ' {
      // 词结束：并入当前行或换行
      if word_w > 0.0 {
        if cur_w <= 0.0 || cur_w + word_w <= max_em {
          if cur_w > 0.0 { cur.write_char(' ') }
          cur.write_string(word.to_string())
          cur_w = cur_w + (if cur_w > 0.0 { 0.28 } else { 0.0 }) + word_w
        } else {
          out.push(cur.to_string())
          cur.reset()
          cur.write_string(word.to_string())
          cur_w = word_w
        }
        word.reset()
        word_w = 0.0
      }
      continue
    }
    let cw = char_em_width(c)
    // 词内字符将超宽：当前词是不可断的长词（CJK 整段/长 URL）——先冲行再冲词
    if word_w + cw > max_em && word_w > 0.0 {
      if cur_w > 0.0 {
        out.push(cur.to_string())
        cur.reset()
        cur_w = 0.0
      }
      out.push(word.to_string())
      word.reset()
      word_w = 0.0
    }
    word.write_char(c)
    word_w = word_w + cw
  }
  // 收尾：残余词并入
  if word_w > 0.0 {
    if cur_w <= 0.0 || cur_w + word_w <= max_em {
      if cur_w > 0.0 { cur.write_char(' ') }
      cur.write_string(word.to_string())
    } else {
      out.push(cur.to_string())
      cur.reset()
      cur.write_string(word.to_string())
    }
  }
  if cur.to_string().length() > 0 { out.push(cur.to_string()) }
  if out.length() == 0 { out.push(line) }
  out
}

///|
/// 宽度感知文本换行入口：先按 \n 硬拆，再逐段做宽度测量换行
fn wrap_text_lines(text : String, font_size : Double, max_width : Double) -> Array[String] {
  let hard_lines = split_lines(text)
  let max_em = max_width / font_size
  let out : Array[String] = []
  for hl in hard_lines.iter() {
    if text_em_width(hl) <= max_em {
      out.push(hl)
    } else {
      for wl in wrap_line_at_width(hl, max_em).iter() {
        out.push(wl)
      }
    }
  }
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
///|
/// 图片 src 判定：http(s)/data URL 才渲染真 <image>，其余（含空）走占位
fn has_url_prefix(s : String) -> Bool {
  let http = "http://"
  let https = "https://"
  let data = "data:"
  if s.length() >= http.length() && s.substring(start=0, end=http.length()) == http {
    true
  } else if s.length() >= https.length() && s.substring(start=0, end=https.length()) == https {
    true
  } else {
    s.length() >= data.length() && s.substring(start=0, end=data.length()) == data
  }
}

///|
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
