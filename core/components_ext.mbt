/// 组件库 v4：按 namethatui.com 组件分类学复刻扩展。
/// 覆盖 actions / inputs / selection / display / layout / navigation / feedback /
/// overlay 八大类，供 Agent 与组件面板消费。

///|
/// 追加扩展组件（独立函数便于 builtin_components 尾部调用）
pub fn extended_components(
  m : Map[String, ComponentDef],
) -> Map[String, ComponentDef] {
  // ---------------- feedback ----------------
  let av : Map[String, NodePatch] = Map::new()
  av.set("info", patch3("primary", "on_primary", 10.0))
  av.set("success", patch3("success", "on_primary", 10.0))
  av.set("error", patch3("error", "on_primary", 10.0))
  av.set("warning", patch3("warning", "on_primary", 10.0))
  m.set("alert", {
    id: "alert",
    kind: "rect",
    description: "警示条：页面级消息（info/success/error/warning），text 为消息文案。",
    variants: av,
    default_variant: "info",
    default_size: (320.0, 52.0),
    default_layout: None,
    category: "feedback",
  })

  let tv : Map[String, NodePatch] = Map::new()
  tv.set("default", patch3("text_primary", "text_on_primary", 8.0))
  m.set("toast", {
    id: "toast",
    kind: "rect",
    description: "轻提示：短暂浮出的操作反馈。",
    variants: tv,
    default_variant: "default",
    default_size: (240.0, 44.0),
    default_layout: None,
    category: "feedback",
  })

  let snv : Map[String, NodePatch] = Map::new()
  snv.set("default", patch3("surface", "text_primary", 8.0))
  m.set("snackbar", {
    id: "snackbar",
    kind: "rect",
    description: "底部通知条（可带动作）。",
    variants: snv,
    default_variant: "default",
    default_size: (300.0, 48.0),
    default_layout: None,
    category: "feedback",
  })

  let skv : Map[String, NodePatch] = Map::new()
  skv.set("text", patch2("surface_variant", 4.0))
  skv.set("circle", patch2("surface_variant", 999.0))
  skv.set("block", patch2("surface_variant", 8.0))
  m.set("skeleton", {
    id: "skeleton",
    kind: "rect",
    description: "加载占位骨屏（text/circle/block）。",
    variants: skv,
    default_variant: "block",
    default_size: (160.0, 16.0),
    default_layout: None,
    category: "feedback",
  })

  let spv : Map[String, NodePatch] = Map::new()
  spv.set("default", patch2("primary", 999.0))
  m.set("spinner", {
    id: "spinner",
    kind: "rect",
    description: "加载中指示环。",
    variants: spv,
    default_variant: "default",
    default_size: (24.0, 24.0),
    default_layout: None,
    category: "feedback",
  })

  let mtv : Map[String, NodePatch] = Map::new()
  mtv.set("default", patch2("surface_variant", 6.0))
  mtv.set("success", patch2("success", 6.0))
  m.set("meter", {
    id: "meter",
    kind: "rect",
    description: "度量条（用量/容量）。",
    variants: mtv,
    default_variant: "default",
    default_size: (140.0, 8.0),
    default_layout: None,
    category: "feedback",
  })

  // ---------------- overlay ----------------
  let dv : Map[String, NodePatch] = Map::new()
  dv.set("default", patch3("surface", "text_primary", 14.0))
  dv.set("modal", patch3("surface", "text_primary", 16.0))
  m.set("dialog", {
    id: "dialog",
    kind: "rect",
    description: "对话框容器（text 为标题）。",
    variants: dv,
    default_variant: "default",
    default_size: (360.0, 220.0),
    default_layout: None,
    category: "overlay",
  })

  let dwv : Map[String, NodePatch] = Map::new()
  dwv.set("left", patch3("surface", "text_primary", 0.0))
  dwv.set("right", patch3("surface", "text_primary", 0.0))
  m.set("drawer", {
    id: "drawer",
    kind: "rect",
    description: "抽屉面板（left/right 侧滑）。",
    variants: dwv,
    default_variant: "right",
    default_size: (300.0, 600.0),
    default_layout: None,
    category: "overlay",
  })

  let ppv : Map[String, NodePatch] = Map::new()
  ppv.set("default", patch3("surface", "text_primary", 10.0))
  m.set("popover", {
    id: "popover",
    kind: "rect",
    description: "气泡卡片（锚点浮层）。",
    variants: ppv,
    default_variant: "default",
    default_size: (220.0, 120.0),
    default_layout: None,
    category: "overlay",
  })

  let ttv : Map[String, NodePatch] = Map::new()
  ttv.set("dark", patch3("text_primary", "surface", 6.0))
  m.set("tooltip", {
    id: "tooltip",
    kind: "rect",
    description: "文字提示气泡。",
    variants: ttv,
    default_variant: "dark",
    default_size: (140.0, 30.0),
    default_layout: None,
    category: "overlay",
  })

  let dmv : Map[String, NodePatch] = Map::new()
  dmv.set("default", patch3("surface", "text_primary", 10.0))
  m.set("menu", {
    id: "menu",
    kind: "rect",
    description: "下拉菜单面板。",
    variants: dmv,
    default_variant: "default",
    default_size: (180.0, 160.0),
    default_layout: None,
    category: "overlay",
  })

  // ---------------- navigation ----------------
  let bcv : Map[String, NodePatch] = Map::new()
  bcv.set("default", patch3("surface", "text_secondary", 6.0))
  m.set("breadcrumb", {
    id: "breadcrumb",
    kind: "rect",
    description: "面包屑路径（text 为路径文案）。",
    variants: bcv,
    default_variant: "default",
    default_size: (220.0, 28.0),
    default_layout: None,
    category: "navigation",
  })

  let pgv2 : Map[String, NodePatch] = Map::new()
  pgv2.set("default", patch2("surface", 8.0))
  pgv2.set("active", patch2("primary", 8.0))
  m.set("pagination", {
    id: "pagination",
    kind: "rect",
    description: "分页控件。",
    variants: pgv2,
    default_variant: "default",
    default_size: (220.0, 32.0),
    default_layout: None,
    category: "navigation",
  })

  let stv : Map[String, NodePatch] = Map::new()
  stv.set("default", patch3("surface", "text_secondary", 999.0))
  stv.set("active", patch3("primary", "on_primary", 999.0))
  m.set("stepper", {
    id: "stepper",
    kind: "rect",
    description: "步骤指示节点。",
    variants: stv,
    default_variant: "default",
    default_size: (28.0, 28.0),
    default_layout: None,
    category: "navigation",
  })

  let nbv : Map[String, NodePatch] = Map::new()
  nbv.set("default", patch3("surface", "text_primary", 0.0))
  nbv.set("primary", patch3("primary", "on_primary", 0.0))
  m.set("navbar", {
    id: "navbar",
    kind: "rect",
    description: "网页顶部导航条。",
    variants: nbv,
    default_variant: "default",
    default_size: (1100.0, 60.0),
    default_layout: None,
    category: "navigation",
  })

  let bnv : Map[String, NodePatch] = Map::new()
  bnv.set("default", patch3("surface", "text_primary", 0.0))
  m.set("bottom_nav", {
    id: "bottom_nav",
    kind: "rect",
    description: "App 底部标签导航。",
    variants: bnv,
    default_variant: "default",
    default_size: (390.0, 56.0),
    default_layout: None,
    category: "navigation",
  })

  // ---------------- forms / inputs ----------------
  let tav : Map[String, NodePatch] = Map::new()
  tav.set("default", patch3("surface", "text_hint", 10.0))
  tav.set("filled", patch3("surface_variant", "text_hint", 10.0))
  m.set("textarea", {
    id: "textarea",
    kind: "rect",
    description: "多行文本输入域。",
    variants: tav,
    default_variant: "default",
    default_size: (280.0, 96.0),
    default_layout: None,
    category: "inputs",
  })

  let sev : Map[String, NodePatch] = Map::new()
  sev.set("default", patch3("surface", "text_hint", 10.0))
  m.set("select", {
    id: "select",
    kind: "rect",
    description: "下拉选择框（text 为当前值）。",
    variants: sev,
    default_variant: "default",
    default_size: (200.0, 40.0),
    default_layout: None,
    category: "inputs",
  })

  let cbv2 : Map[String, NodePatch] = Map::new()
  cbv2.set("default", patch3("surface", "text_hint", 10.0))
  m.set("combobox", {
    id: "combobox",
    kind: "rect",
    description: "可输入可选择的组合框。",
    variants: cbv2,
    default_variant: "default",
    default_size: (220.0, 40.0),
    default_layout: None,
    category: "inputs",
  })

  let dpv : Map[String, NodePatch] = Map::new()
  dpv.set("default", patch3("surface", "text_hint", 10.0))
  m.set("datepicker", {
    id: "datepicker",
    kind: "rect",
    description: "日期选择输入。",
    variants: dpv,
    default_variant: "default",
    default_size: (160.0, 40.0),
    default_layout: None,
    category: "inputs",
  })

  let fuv : Map[String, NodePatch] = Map::new()
  fuv.set("default", patch3("surface_variant", "text_hint", 12.0))
  fuv.set("dashed", patch3("surface", "text_hint", 12.0))
  m.set("file_upload", {
    id: "file_upload",
    kind: "rect",
    description: "文件上传区（text 为提示文案）。",
    variants: fuv,
    default_variant: "default",
    default_size: (280.0, 120.0),
    default_layout: None,
    category: "inputs",
  })

  // ---------------- display ----------------
  let rgv : Map[String, NodePatch] = Map::new()
  rgv.set("off", patch2("surface_variant", 4.0))
  rgv.set("on", patch2("warning", 4.0))
  m.set("rating", {
    id: "rating",
    kind: "rect",
    description: "评分星星（单个星位）。",
    variants: rgv,
    default_variant: "on",
    default_size: (22.0, 22.0),
    default_layout: None,
    category: "display",
  })

  let tgv : Map[String, NodePatch] = Map::new()
  tgv.set(
    "default",
    patch3("secondary_container", "on_secondary_container", 6.0),
  )
  tgv.set("outline", patch2("surface", 6.0))
  m.set("tag", {
    id: "tag",
    kind: "rect",
    description: "内容标签（同 chip 但用于内容分类）。",
    variants: tgv,
    default_variant: "default",
    default_size: (56.0, 24.0),
    default_layout: None,
    category: "display",
  })

  let stv2 : Map[String, NodePatch] = Map::new()
  stv2.set("default", patch3("surface", "text_primary", 12.0))
  m.set("stat", {
    id: "stat",
    kind: "rect",
    description: "统计数字块（text 为数值）。",
    variants: stv2,
    default_variant: "default",
    default_size: (140.0, 80.0),
    default_layout: None,
    category: "display",
  })

  let kbdv : Map[String, NodePatch] = Map::new()
  kbdv.set("default", patch3("surface_variant", "text_primary", 5.0))
  m.set("kbd", {
    id: "kbd",
    kind: "rect",
    description: "键盘按键样式（text 为键名）。",
    variants: kbdv,
    default_variant: "default",
    default_size: (26.0, 24.0),
    default_layout: None,
    category: "display",
  })

  let tbv2 : Map[String, NodePatch] = Map::new()
  tbv2.set("default", patch3("surface", "text_primary", 8.0))
  tbv2.set("striped", patch3("surface_variant", "text_primary", 8.0))
  m.set("table", {
    id: "table",
    kind: "rect",
    description: "数据表容器。",
    variants: tbv2,
    default_variant: "default",
    default_size: (480.0, 200.0),
    default_layout: None,
    category: "display",
  })

  // ---------------- layout ----------------
  let acv : Map[String, NodePatch] = Map::new()
  acv.set("default", patch3("surface", "text_primary", 10.0))
  acv.set("expanded", patch3("surface_variant", "text_primary", 10.0))
  m.set("accordion", {
    id: "accordion",
    kind: "rect",
    description: "折叠面板行（text 为标题）。",
    variants: acv,
    default_variant: "default",
    default_size: (320.0, 48.0),
    default_layout: None,
    category: "layout",
  })

  let cav : Map[String, NodePatch] = Map::new()
  cav.set("default", patch2("surface_variant", 12.0))
  cav.set("wide", patch2("surface_variant", 12.0))
  m.set("carousel", {
    id: "carousel",
    kind: "rect",
    description: "轮播容器。",
    variants: cav,
    default_variant: "default",
    default_size: (320.0, 180.0),
    default_layout: None,
    category: "layout",
  })

  let tlv : Map[String, NodePatch] = Map::new()
  tlv.set("default", patch2("primary", 999.0))
  m.set("timeline", {
    id: "timeline",
    kind: "rect",
    description: "时间线节点。",
    variants: tlv,
    default_variant: "default",
    default_size: (12.0, 12.0),
    default_layout: None,
    category: "layout",
  })

  let bgv : Map[String, NodePatch] = Map::new()
  bgv.set("default", patch2("surface_variant", 8.0))
  bgv.set("attached", patch2("surface_variant", 0.0))
  m.set("button_group", {
    id: "button_group",
    kind: "rect",
    description: "按钮组容器。",
    variants: bgv,
    default_variant: "default",
    default_size: (180.0, 36.0),
    default_layout: None,
    category: "actions",
  })

  let lkv : Map[String, NodePatch] = Map::new()
  lkv.set("default", patch2("primary", 0.0))
  m.set("link", {
    id: "link",
    kind: "text",
    description: "超链接文本（text 为链接文案）。",
    variants: lkv,
    default_variant: "default",
    default_size: (80.0, 20.0),
    default_layout: None,
    category: "actions",
  })

  m
}
