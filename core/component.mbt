///|
/// 组件系统：Agent 可发现、可实例化、可变体的设计组件库。
///
/// 每个组件定义（ComponentDef）是一个"配方"：
/// - 有一组语义属性（variant: primary / secondary / danger）
/// - 有默认的布局/样式（映射到设计令牌）
/// Agent 通过 `instantiate(def, variant)` 获得可直接放入文档的 Node。
pub(all) struct ComponentDef {
  id : String
  kind : String // "frame" | "rect" | "text"
  description : String
  variants : Map[String, NodePatch]
  default_variant : String
  default_size : (Double, Double)
  default_layout : StackLayout?
  category : String
}

///|
fn patch1(f : String) -> NodePatch {
  { ..NodePatch::empty(), fill: Some(f), }
}

///|
fn patch2(f : String, r : Double) -> NodePatch {
  { ..NodePatch::empty(), fill: Some(f), corner_radius: Some(r), }
}

///|
fn patch3(f : String, tc : String, r : Double) -> NodePatch {
  {
    ..NodePatch::empty(),
    fill: Some(f),
    text_color: Some(tc),
    corner_radius: Some(r),
  }
}

///|
/// 输入类变体用：底 + 文字角色 + 圆角 + 1px hairline 描边——浅色主题下
/// surface_variant 与画布仅 1.03~1.05:1，无描边时字段边界不可辨（审计
/// signup/checkout 字段边界残留）
fn patch4(f : String, tc : String, r : Double, s : String) -> NodePatch {
  {
    ..NodePatch::empty(),
    fill: Some(f),
    text_color: Some(tc),
    corner_radius: Some(r),
    stroke: Some(s),
  }
}

///|
fn patch_font(size : Double, tc : String) -> NodePatch {
  { ..NodePatch::empty(), font_size: Some(size), text_color: Some(tc), }
}

///|
/// 内置组件库（Agent 的调色板）
pub fn builtin_components() -> Map[String, ComponentDef] {
  let m : Map[String, ComponentDef] = Map::new()

  let bv : Map[String, NodePatch] = Map::new()
  bv.set("primary", patch3("primary", "on_primary", 8.0))
  // secondary 容器底配 on_secondary_container（Material/HIG 的 tonal 按钮口径，
  // 与 chip 同语义）：文字角色随容器底翻转，recolor 反查也单一化
  bv.set(
    "secondary",
    patch4("secondary_container", "on_secondary_container", 8.0, "outline"),
  )
  bv.set("danger", patch3("error", "on_primary", 8.0))
  m.set("button", {
    id: "button",
    kind: "rect",
    description: "操作按钮。支持 primary/secondary/danger。",
    variants: bv,
    default_variant: "primary",
    default_size: (120.0, 44.0),
    default_layout: None,
    category: "actions",
  })

  let iv : Map[String, NodePatch] = Map::new()
  // 输入底用中性 surface_variant（输入层不是品牌 tint 层——HIG/
  // 鸿蒙的 filled field 都是中性灰阶，品牌色留给主操作）；占位文字
  // 绑 text_hint：占位是提示不是已填值，且暗色下出厂黑字会撞色（审计 R1）；
  // 1px outline 描边补字段边界（浅色下底色与画布仅 1.03~1.05:1）
  iv.set("default", patch4("surface_variant", "text_hint", 8.0, "outline"))
  iv.set("filled", patch4("surface_variant", "text_hint", 12.0, "outline"))
  m.set("text_input", {
    id: "text_input",
    kind: "rect",
    description: "文本输入框。",
    variants: iv,
    default_variant: "default",
    default_size: (280.0, 44.0),
    default_layout: None,
    category: "inputs",
  })

  let cv : Map[String, NodePatch] = Map::new()
  // card 文字绑 text_primary：模板常直接把文案写在卡上，暗色主题下
  // 出厂 #111111 压 surface 深底只有 1.35:1（审计 R1/dashboard/profile）
  cv.set("elevated", patch3("surface", "text_primary", 12.0))
  m.set("card", {
    id: "card",
    kind: "frame",
    description: "卡片容器。垂直布局。",
    variants: cv,
    default_variant: "elevated",
    default_size: (320.0, 200.0),
    default_layout: Some({
      dir: Vertical,
      gap: 8.0,
      justify: Start,
      padding: { top: 16.0, right: 16.0, bottom: 16.0, left: 16.0, },
    }),
    category: "layout",
  })

  let av : Map[String, NodePatch] = Map::new()
  // app_bar 标题随底色取对文字角色：surface→text_primary、primary→on_primary
  // （出厂 #111111 压主色蓝底 3.4~3.6:1 不达标，审计 dashboard:top_bar）
  av.set("surface", patch3("surface", "text_primary", 0.0))
  av.set("primary", patch3("primary", "on_primary", 0.0))
  m.set("app_bar", {
    id: "app_bar",
    kind: "rect",
    description: "顶部导航栏。",
    variants: av,
    default_variant: "surface",
    default_size: (390.0, 56.0),
    default_layout: None,
    category: "layout",
  })

  let dv : Map[String, NodePatch] = Map::new()
  dv.set("default", patch1("outline_variant"))
  m.set("divider", {
    id: "divider",
    kind: "rect",
    description: "分隔线。",
    variants: dv,
    default_variant: "default",
    default_size: (320.0, 1.0),
    default_layout: None,
    category: "layout",
  })

  let hv : Map[String, NodePatch] = Map::new()
  hv.set("h1", patch_font(32.0, "text_primary"))
  hv.set("h2", patch_font(24.0, "text_primary"))
  hv.set("h3", patch_font(20.0, "text_primary"))
  hv.set("h4", patch_font(16.0, "text_primary"))
  m.set("heading", {
    id: "heading",
    kind: "text",
    description: "标题。h1=32px h2=24px h3=20px h4=16px。",
    variants: hv,
    default_variant: "h2",
    default_size: (280.0, 36.0),
    default_layout: None,
    category: "display",
  })

  let tv : Map[String, NodePatch] = Map::new()
  tv.set("body", patch_font(14.0, "text_secondary"))
  tv.set("caption", patch_font(12.0, "text_hint"))
  m.set("body_text", {
    id: "body_text",
    kind: "text",
    description: "正文。body=14px caption=12px。",
    variants: tv,
    default_variant: "body",
    default_size: (280.0, 20.0),
    default_layout: None,
    category: "display",
  })

  let gv : Map[String, NodePatch] = Map::new()
  gv.set("primary", patch3("primary", "on_primary", 12.0))
  gv.set("success", patch3("success", "on_primary", 12.0))
  // warning/error 语义档：web_landing 特性卡按 primary/success/warning 取
  // 语义色，变体表缺 warning 时 place_comp 静默拒绝、第三卡图标丢失
  // （第 2 轮回归 feat_icon2）——语义色档在此补齐
  gv.set("warning", patch3("warning", "on_primary", 12.0))
  gv.set("error", patch3("error", "on_primary", 12.0))
  m.set("badge", {
    id: "badge",
    kind: "rect",
    description: "徽标。",
    variants: gv,
    default_variant: "primary",
    default_size: (64.0, 24.0),
    default_layout: None,
    category: "display",
  })

  let rv : Map[String, NodePatch] = Map::new()
  rv.set("default", patch2("surface_variant", 0.0))
  rv.set("outline", patch2("surface", 0.0))
  m.set("rect", {
    id: "rect",
    kind: "rect",
    description: "通用矩形：面板/背景条/装饰块，颜色与圆角由 update 设置。",
    variants: rv,
    default_variant: "default",
    default_size: (200.0, 100.0),
    default_layout: None,
    category: "layout",
  })

  // ------------------------------------------------------------------
  // 扩展组件库（v3）：选择控件 / 导航 / 内容展示
  // ------------------------------------------------------------------

  let cbv : Map[String, NodePatch] = Map::new()
  cbv.set("unchecked", patch3("surface", "text_secondary", 4.0))
  cbv.set("checked", patch3("primary", "on_primary", 4.0))
  m.set("checkbox", {
    id: "checkbox",
    kind: "rect",
    description: "复选框。unchecked/checked。",
    variants: cbv,
    default_variant: "unchecked",
    default_size: (22.0, 22.0),
    default_layout: None,
    category: "selection",
  })

  let sv : Map[String, NodePatch] = Map::new()
  sv.set("off", patch3("surface_variant", "text_secondary", 999.0))
  sv.set("on", patch3("primary", "on_primary", 999.0))
  m.set("switch", {
    id: "switch",
    kind: "rect",
    description: "开关。off/on。",
    variants: sv,
    default_variant: "on",
    default_size: (46.0, 26.0),
    default_layout: None,
    category: "selection",
  })

  let rdv : Map[String, NodePatch] = Map::new()
  rdv.set("unchecked", patch2("surface", 999.0))
  rdv.set("checked", patch2("primary", 999.0))
  m.set("radio", {
    id: "radio",
    kind: "rect",
    description: "单选圆点。unchecked/checked。",
    variants: rdv,
    default_variant: "unchecked",
    default_size: (20.0, 20.0),
    default_layout: None,
    category: "selection",
  })

  let avv : Map[String, NodePatch] = Map::new()
  // avatar 常放首字母 text，文字角色随容器底（on_secondary_container）
  avv.set(
    "circle",
    patch3("secondary_container", "on_secondary_container", 999.0),
  )
  avv.set(
    "square",
    patch3("secondary_container", "on_secondary_container", 8.0),
  )
  m.set("avatar", {
    id: "avatar",
    kind: "rect",
    description: "头像占位。circle/square。",
    variants: avv,
    default_variant: "circle",
    default_size: (40.0, 40.0),
    default_layout: None,
    category: "display",
  })

  let sbv : Map[String, NodePatch] = Map::new()
  sbv.set("default", patch4("surface_variant", "text_hint", 999.0, "outline"))
  sbv.set("filled", patch4("surface", "text_hint", 10.0, "outline"))
  m.set("search_bar", {
    id: "search_bar",
    kind: "rect",
    description: "搜索框（占位文字 text 设置）。",
    variants: sbv,
    default_variant: "default",
    default_size: (240.0, 38.0),
    default_layout: None,
    category: "inputs",
  })

  let pgv : Map[String, NodePatch] = Map::new()
  pgv.set("default", patch2("primary", 999.0))
  pgv.set("secondary", patch2("secondary_container", 999.0))
  m.set("progress", {
    id: "progress",
    kind: "rect",
    description: "进度条。宽度表示进度。",
    variants: pgv,
    default_variant: "default",
    default_size: (180.0, 6.0),
    default_layout: None,
    category: "display",
  })

  let chv : Map[String, NodePatch] = Map::new()
  chv.set(
    "default",
    patch4("secondary_container", "on_secondary_container", 999.0, "outline"),
  )
  chv.set("selected", patch3("primary", "on_primary", 999.0))
  m.set("chip", {
    id: "chip",
    kind: "rect",
    description: "筛选/标签 chip。",
    variants: chv,
    default_variant: "default",
    default_size: (72.0, 30.0),
    default_layout: None,
    category: "display",
  })

  let fbv : Map[String, NodePatch] = Map::new()
  fbv.set("primary", patch3("primary", "on_primary", 999.0))
  fbv.set("error", patch3("error", "on_primary", 999.0))
  m.set("fab", {
    id: "fab",
    kind: "rect",
    description: "悬浮操作按钮（＋ 语义）。",
    variants: fbv,
    default_variant: "primary",
    default_size: (56.0, 56.0),
    default_layout: None,
    category: "actions",
  })

  let liv : Map[String, NodePatch] = Map::new()
  liv.set("default", patch3("surface", "text_primary", 10.0))
  liv.set(
    "highlighted",
    patch3("secondary_container", "on_secondary_container", 10.0),
  )
  m.set("list_item", {
    id: "list_item",
    kind: "rect",
    description: "列表行（text 为标题）。",
    variants: liv,
    default_variant: "default",
    default_size: (320.0, 56.0),
    default_layout: None,
    category: "layout",
  })

  let tbv : Map[String, NodePatch] = Map::new()
  // tab_bar 是全宽底边条：圆角 0（norms.mbt:75 与 norm_is_full_bleed_component
  // 同一判据，出厂圆角 10 会在 critique 自报偏差）；文字绑 text_secondary，
  // active 变体主色底配 on_primary
  tbv.set("default", patch3("surface_variant", "text_secondary", 0.0))
  tbv.set("active", patch3("primary", "on_primary", 0.0))
  m.set("tab_bar", {
    id: "tab_bar",
    kind: "rect",
    description: "标签栏容器。",
    variants: tbv,
    default_variant: "default",
    default_size: (390.0, 56.0),
    default_layout: None,
    category: "navigation",
  })

  let imv : Map[String, NodePatch] = Map::new()
  imv.set("default", patch2("surface_variant", 12.0))
  imv.set("rounded", patch2("surface_variant", 16.0))
  m.set("image", {
    id: "image",
    kind: "image",
    description: "图片占位（灰底圆角）。",
    variants: imv,
    default_variant: "rounded",
    default_size: (200.0, 140.0),
    default_layout: None,
    category: "display",
  })

  let slv : Map[String, NodePatch] = Map::new()
  slv.set("default", patch2("surface_variant", 999.0))
  slv.set("active", patch2("primary", 999.0))
  m.set("slider", {
    id: "slider",
    kind: "rect",
    description: "滑杆轨道。",
    variants: slv,
    default_variant: "active",
    default_size: (200.0, 4.0),
    default_layout: None,
    category: "inputs",
  })

  let m2 = extended_components(extended_components_v5(m))
  m2
}

///|
/// 组件默认 elevation（视觉语言「生命感」支柱：层次靠阴影语言而非颜色）。
///
/// 三档对齐 render_svg 的 e1/e2/e3 滤镜，语义取 Apple HIG / HarmonyOS /
/// Material 的共识分层——内容层浮起一档，临时浮层两档，模态层三档：
/// - e1 内容卡片：card(elevated)、stat
/// - e2 临时浮层：fab、popover、menu、tooltip、toast、snackbar、hover_card
/// - e3 模态层：dialog、drawer、command_palette
/// 其余组件贴面（"none"）。查表而非扩 NodePatch：NodePatch 是 pub(all)
/// 被多包字面量构造，加字段即全仓连锁破坏；elevation 是组件语义，归组件层。
pub fn component_default_shadow(comp_id : String, variant : String) -> String {
  match comp_id {
    "card" => if variant == "elevated" || variant == "" { "e1" } else { "none" }
    "stat" => "e1"
    "fab" | "popover" | "menu" | "tooltip" | "toast" | "snackbar" | "hover_card" =>
      "e2"
    "dialog" | "drawer" | "command_palette" => "e3"
    _ => "none"
  }
}

///|
/// 居中文字组件族：形状+文字在视觉上居中是 HIG/鸿蒙/Material 共识
/// （按钮/胶囊/chip/徽标）。节点默认 text_align="left" 是文字节点的
/// 通用缺省，这里在组件语义层覆写——SVG/HTML 渲染与导出同源受益，
/// 不在渲染层按组件名单硬编码。
fn component_centers_text(comp_id : String) -> Bool {
  comp_id == "button" ||
  comp_id == "fab" ||
  comp_id == "chip" ||
  comp_id == "tag" ||
  comp_id == "badge" ||
  comp_id == "button_group" ||
  comp_id == "toggle_group"
}

///|
/// 实例化组件：返回可直接放入文档的 Node
pub fn instantiate_component(
  def : ComponentDef,
  id : String,
  variant? : String = "",
  tokens? : DesignTokens = DesignTokens::default(),
) -> Node {
  let v = if variant == "" { def.default_variant } else { variant }
  let kind : NodeKind = match def.kind {
    "frame" => Frame
    "text" => Text
    "image" => Image
    "group" => Group
    _ => Rect
  }
  let (w, h) = def.default_size
  let made = Node::make(id, kind)
  let centered = component_centers_text(def.id)
  let base = {
    ..made,
    width: Fixed(w),
    height: Fixed(h),
    layout: def.default_layout,
    component: def.id,
    style: {
      ..made.style,
      shadow: component_default_shadow(def.id, v),
      text_align: if centered { "center" } else { made.style.text_align },
    },
  }
  match def.variants.get(v) {
    Some(p) => {
      let mut n = base
      match p.fill {
        Some(f) => {
          let hex = tokens.resolve_color(f)
          n = { ..n, style: { ..n.style, fill: hex, }, }
        }
        None => ()
      }
      match p.stroke {
        Some(s) => {
          let hex = tokens.resolve_color(s)
          n = { ..n, style: { ..n.style, stroke: hex, }, }
        }
        None => ()
      }
      match p.corner_radius {
        Some(r) => n = { ..n, style: { ..n.style, corner_radius: r, }, }
        None => ()
      }
      match p.font_size {
        Some(f) => n = { ..n, style: { ..n.style, font_size: f, }, }
        None => ()
      }
      match p.text_color {
        Some(tc) => {
          let hex = tokens.resolve_color(tc)
          n = { ..n, style: { ..n.style, text_color: hex, }, }
        }
        None => ()
      }
      n
    }
    None => base
  }
}

///|
/// 组件清单 JSON（Agent 发现用）
pub fn list_components_json(defs : Map[String, ComponentDef]) -> String {
  let parts : Array[String] = []
  for id in defs.keys() {
    match defs.get(id) {
      Some(def) => {
        let vs : Array[String] = []
        for v in def.variants.keys() {
          vs.push("\"\{v}\"")
        }
        let vj = jstr(vs)
        // 组件规范随条目下发（component_norm）：Agent 在选组件的瞬间就能看到
        // 尺寸/圆角规范——事前指导，比 critique 事后纠正省一整轮
        let norm_j = match component_norm(def.id) {
          Some(t) => ",\"norm\":\"\{t}\""
          None => ""
        }
        parts.push(
          "{\"id\":\"\{def.id}\",\"kind\":\"\{def.kind}\",\"category\":\"\{def.category}\",\"variants\":[\{vj}],\"default_size\":[\{def.default_size.0.to_string()},\{def.default_size.1.to_string()}]\{norm_j}}",
        )
      }
      None => ()
    }
  }
  let j = jstr(parts)
  "[\{j}]"
}

///|
fn jstr(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}
