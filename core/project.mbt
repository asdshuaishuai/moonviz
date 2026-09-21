///|
/// 多画板项目：真实原型有多个页面（登录→首页→详情→设置），
/// 画板之间有导航流（Flow），共享设计令牌与组件库。
pub(all) struct ArtboardMeta {
  id : String
  name : String
  width : Double
  height : Double
  mut doc : Document
}

///|
pub(all) struct FlowEdge {
  from : String // artboard id
  to : String
  trigger : String // "tap:login" / "swipe:left" 等
}

///|
pub(all) struct Project {
  mut artboards : Map[String, ArtboardMeta]
  mut flows : Array[FlowEdge]
  mut tokens : DesignTokens
  mut components : Map[String, ComponentDef]
  mut user_components : Map[String, UserComponentDef]
  /// 组件多态状态：node_id → 状态定义（default/pressed/disabled/… 的补丁集）。
  /// 存于节点名标记，会话内可变模型由此重建；作用于渲染前的节点变换。
  mut node_states : Map[String, ComponentStateDef]
  mut revision : Int
  /// 令牌自定义覆盖（set_token 产生）：随 canonical MBT frontmatter
  /// `tokens:` 段往返；load 时在主题恢复后叠加应用。
  mut token_overrides : Map[String, String]?
  /// 当前主题名（light/dark/nord/…）：随 canonical MBT frontmatter 往返，
  /// 决定渲染层画布底色等 tokens 派生视觉。节点 fill 已是字面量，
  /// 由 apply_theme 的角色重着色负责，加载路径只恢复 tokens 不再重着色。
  mut active_theme : String
}

///|
pub fn Project::new() -> Project {
  {
    artboards: Map::new(),
    flows: [],
    tokens: DesignTokens::default(),
    components: builtin_components(),
    user_components: Map::new(),
    node_states: Map::new(),
    revision: 1,
    active_theme: "light",
    token_overrides: None,
  }
}

///|
/// 用从唯一 MBT 源码重建的项目快照原子替换临时计算缓存。
///
/// Studio/CLI 不会持久化这个 Project；每次载入都应来自 `.mbt.md`，它只是
/// 当前命令批次内的可变计算模型。
pub fn Project::replace_with(self : Project, source : Project) -> Unit {
  self.artboards = source.artboards
  self.flows = source.flows
  self.tokens = source.tokens
  self.components = source.components
  // 会话级注册表同样必须随快照替换：漏掉它们会让 load 后重建的
  // 组件状态表与用户组件注册表凭空消失（前者是状态多态的行为来源）。
  self.user_components = source.user_components
  self.node_states = source.node_states
  self.revision = source.revision
  self.active_theme = source.active_theme
  self.token_overrides = source.token_overrides
}

// ---------------------------------------------------------------------------
// 画板管理
// ---------------------------------------------------------------------------

///|
pub fn Project::create_artboard(
  self : Project,
  name~ : String,
  width? : Double = 390.0,
  height? : Double = 844.0,
) -> String {
  let id = sanitize_id(name)
  let doc = Document::new({ width, height })
  self.artboards.set(id, { id, name, width, height, doc })
  self.revision = self.revision + 1
  id
}

///|
/// 在画板上放置组件实例
pub fn Project::place_component(
  self : Project,
  artboard~ : String,
  component_id~ : String,
  instance_id~ : String,
  variant? : String = "",
  parent_id? : String = "",
  x? : Double = 0.0,
  y? : Double = 0.0,
  args? : Map[String, String] = Map::new(),
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) =>
      // 用户组件优先：自定义组件与内置同权，同名时自定义遮蔽内置
      match self.user_components.get(component_id) {
        Some(udef) => {
          match place_user_component(
            ab.doc,
            udef,
            instance_id,
            variant~,
            args~,
            dx=x,
            dy=y,
          ) {
            Err(error) => Err(error)
            Ok(root_id) => {
              self.revision = self.revision + 1
              // node 透传实例真实根节点 id（instance::<cid>）：
              // 调用方据此做 move/update/query（见 usercomp.mbt 的 id 命名契约）。
              Ok(
                "{\"ok\":true,\"op\":\"place\",\"node\":\"\{root_id}\",\"instance\":\"\{instance_id}\",\"component\":\"\{component_id}\",\"source\":\"user\",\"artboard\":\"\{artboard}\"}",
              )
            }
          }
        }
        None =>
          match self.components.get(component_id) {
            None => Err("unknown_component: \{component_id}")
            Some(def) => {
          let node = instantiate_component(
            def,
            instance_id,
            variant~,
            tokens=self.tokens,
          )
          // 统一边界策略：负坐标夹回 0；右上不夹紧——按默认尺寸夹紧会在
          // 先 place 后 resize 的流程里留下被夹坏的坐标（模板 2×2 网格因此
          // 重叠）。越界由 contained_in_parent 谓词显式报告为视觉债。
          let safe_x = if x < 0.0 { 0.0 } else { x }
          let safe_y = if y < 0.0 { 0.0 } else { y }
          let placed = { ..node, x: AlignStart(safe_x), y: AlignStart(safe_y) }
          let pid = if parent_id == "" { "root" } else { parent_id }
          match pid {
            "root" => {
              let _ = ab.doc.insert_node(placed, "root")
              self.revision = self.revision + 1
              Ok(
                "{\"ok\":true,\"op\":\"place\",\"node\":\"\{instance_id}\",\"x\":\{safe_x},\"y\":\{safe_y},\"artboard\":\"\{artboard}\"}",
              )
            }
            _ =>
              match ab.doc.insert_node(placed, pid) {
                true => {
                  self.revision = self.revision + 1
                  Ok(
                    "{\"ok\":true,\"op\":\"place\",\"node\":\"\{instance_id}\",\"x\":\{safe_x},\"y\":\{safe_y},\"parent\":\"\{pid}\"}",
                  )
                }
                false => Err("unknown_parent: \{pid}")
              }
          }
            }
          }
      }
  }
}

///|
fn size_value(spec : SizeSpec, fallback : Double) -> Double {
  match spec {
    Fixed(v) => v
    _ => fallback
  }
}

///|
/// 删除画板：至少保留一个画板；同时清理引用该画板的交互流。
/// 节点随画板 doc 整体移除，无需逐个 delete。
pub fn Project::delete_artboard(self : Project, id~ : String) -> Result[String, String] {
  if self.artboards.size() <= 1 {
    return Err("cannot_delete_last_artboard")
  }
  match self.artboards.get(id) {
    None => Err("unknown_artboard: \{id}")
    Some(_) => {
      self.artboards.remove(id)
      let kept : Array[FlowEdge] = self.flows.filter(f => f.from != id && f.to != id)
      let removed_flows = self.flows.length() - kept.length()
      self.flows = kept
      self.revision = self.revision + 1
      Ok(
        "{\"ok\":true,\"op\":\"delete_artboard\",\"artboard\":\"\{id}\",\"flows_removed\":\{removed_flows}}",
      )
    }
  }
}

///|
fn max_coord(v : Double) -> Double {
  if v < 0.0 {
    0.0
  } else {
    v
  }
}

///|
fn clamp_coord(v : Double, lo : Double, hi : Double) -> Double {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

// ---------------------------------------------------------------------------
// 导航流
// ---------------------------------------------------------------------------

///|
pub fn Project::add_flow(
  self : Project,
  from~ : String,
  to~ : String,
  trigger? : String = "tap",
) -> Unit {
  self.flows.push({ from, to, trigger })
}

///|
pub fn Project::flow_json(self : Project) -> String {
  let parts : Array[String] = []
  for e in self.flows.iter() {
    parts.push(
      "{\"from\":\"\{e.from}\",\"to\":\"\{e.to}\",\"trigger\":\"\{e.trigger}\"}",
    )
  }
  let j = join_str4(parts)
  "[\{j}]"
}

///|
fn join_str4(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 查询
// ---------------------------------------------------------------------------

///|
pub fn Project::list_artboards_json(self : Project) -> String {
  let parts : Array[String] = []
  for id in self.artboards.keys() {
    match self.artboards.get(id) {
      Some(ab) => {
        let nv = ab.doc.nodes.size()
        parts.push(
          "{\"id\":\"\{ab.id}\",\"name\":\"\{ab.name}\",\"width\":\{ab.width},\"height\":\{ab.height},\"nodes\":\{nv}}",
        )
      }
      None => ()
    }
  }
  let j = join_str4(parts)
  "[\{j}]"
}

///|
/// 按条件查询画板中的节点
pub fn Project::query_nodes(
  self : Project,
  artboard~ : String,
  kind? : String = "",
  component? : String = "",
  text_contains? : String = "",
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let results : Array[String] = []
      let layout = solve(ab.doc)
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) => {
            let kind_match = kind == "" || kind_of(n) == kind
            let comp_match = component == "" || n.component == component
            let text_match = text_contains == "" ||
              n.text.contains(text_contains)
            if kind_match && comp_match && text_match && id != "root" {
              match layout.rect_of(id) {
                Some(r) =>
                  results.push(
                    query_node_json(id, n, r),
                  )
                None => ()
              }
            }
          }
          None => ()
        }
      }
      Ok("[\{join_str4(results)}]")
    }
  }
}

///|
/// 单个节点的查询 JSON。
/// 必须与 NodeStyle / Node 的完整字段保持同步：Studio 属性面板、
/// 图层名与布局控件都从这里取值；漏字段会让引擎已支持的能力在界面上不可达。
fn query_node_json(id : String, n : Node, r : Rect) -> String {
  let layout_json = match n.layout {
    Some(l) =>
      "{\"dir\":\"" +
      (match l.dir {
        Vertical => "vertical"
        Horizontal => "horizontal"
      }) +
      "\",\"gap\":" +
      l.gap.to_string() +
      ",\"justify\":\"" +
      (match l.justify {
        Start => "start"
        Center => "center"
        End => "end"
      }) +
      "\",\"padding\":" +
      l.padding.top.to_string() +
      "}"
    None => "null"
  }
  let out = StringBuilder::new()
  out.write_string("{\"id\":\"" + id + "\",")
  out.write_string("\"kind\":\"" + kind_of(n) + "\",")
  out.write_string("\"component\":\"" + json_escape_field(n.component) + "\",")
  out.write_string("\"name\":\"" + json_escape_field(n.name) + "\",")
  out.write_string("\"text\":\"" + json_escape_field(n.text) + "\",")
  out.write_string(
    "\"rect\":{\"x\":" +
    r.x.to_string() +
    ",\"y\":" +
    r.y.to_string() +
    ",\"w\":" +
    r.width.to_string() +
    ",\"h\":" +
    r.height.to_string() +
    "},",
  )
  out.write_string("\"constraint\":\"" + n.constraint + "\",")
  out.write_string("\"layout\":" + layout_json + ",")
  out.write_string("\"width_mode\":\"" + size_mode(n.width) + "\",")
  out.write_string("\"height_mode\":\"" + size_mode(n.height) + "\",")
  out.write_string("\"style\":{")
  out.write_string("\"fill\":\"" + n.style.fill + "\",")
  out.write_string("\"text_color\":\"" + n.style.text_color + "\",")
  out.write_string("\"stroke\":\"" + n.style.stroke + "\",")
  out.write_string("\"stroke_width\":" + n.style.stroke_width.to_string() + ",")
  out.write_string("\"radius\":" + n.style.corner_radius.to_string() + ",")
  out.write_string("\"opacity\":" + n.style.opacity.to_string() + ",")
  out.write_string("\"font_size\":" + n.style.font_size.to_string() + ",")
  out.write_string("\"weight\":\"" + n.style.font_weight + "\",")
  out.write_string("\"shadow\":\"" + n.style.shadow + "\",")
  out.write_string("\"rotate\":" + n.style.rotate.to_string() + ",")
  out.write_string("\"blur\":" + n.style.blur.to_string() + ",")
  out.write_string("\"blend\":\"" + n.style.blend + "\",")
  out.write_string("\"line\":" + n.style.line_height.to_string() + ",")
  out.write_string("\"tracking\":" + n.style.tracking.to_string() + ",")
  out.write_string("\"align\":\"" + n.style.text_align + "\",")
  out.write_string("\"italic\":\"" + n.style.font_style + "\",")
  out.write_string("\"dash\":\"" + n.style.stroke_dash + "\",")
  out.write_string(
    "\"visible\":" + (if n.style.visible { "true" } else { "false" }),
  )
  out.write_string("}}")
  out.to_string()
}

///|
/// 尺寸规格 → 模式名（供属性面板回显）
fn size_mode(s : SizeSpec) -> String {
  match s {
    Fixed(_) => "fixed"
    Fill => "fill"
    Hug => "hug"
  }
}

///|
fn is_frame_kind(n : Node) -> Bool {
  match n.kind {
    Frame => true
    _ => false
  }
}

///|
fn is_rect_kind(n : Node) -> Bool {
  match n.kind {
    Rect => true
    _ => false
  }
}

///|
fn is_text_kind(n : Node) -> Bool {
  match n.kind {
    Text => true
    _ => false
  }
}

///|
fn kind_of(n : Node) -> String {
  match n.kind {
    Frame => "frame"
    Group => "group"
    Rect => "rect"
    Text => "text"
    Image => "image"
  }
}

///|
/// JSON 字符串字段转义（query 输出用）
fn json_escape_field(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s.iter() {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\t' => sb.write_string("\\t")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

// ---------------------------------------------------------------------------
// 设计 Lint（超越不崩谓词的质量检查）
// ---------------------------------------------------------------------------

///|
pub(all) struct DesignLint {
  rule : String
  severity : String // "error" | "warning" | "info"
  node_id : String
  message : String
  suggestion : String
}

///|
/// 设计质量检查：对比度/触控目标/间距/一致性
pub fn Project::lint(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let layout = solve(ab.doc)
      let lints : Array[String] = []
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) => {
            if id == "root" {
              continue
            }
            match layout.rect_of(id) {
              Some(r) => {
                // L1: 触控目标（最小 44×44）
                if r.width < 44.0 || r.height < 44.0 {
                  if n.component == "button" ||
                    n.component == "text_input" ||
                    is_rect_kind(n) {
                    lints.push(
                      lint_json(
                        "touch_target",
                        "warning",
                        id,
                        "触控目标 \{r.width.to_int()}×\{r.height.to_int()} 小于 44×44",
                        "增大到至少 44×44 以满足无障碍标准",
                      ),
                    )
                  }
                }
                // L2: 文字对比度
                if is_text_kind(n) || n.text != "" {
                  let fg = n.style.text_color
                  let bg = if n.style.fill != "none" && n.style.fill != "" {
                    n.style.fill
                  } else {
                    "#FFFFFF"
                  }
                  let ratio = contrast_ratio(fg, bg)
                  if ratio < 4.5 {
                    lints.push(
                      lint_json(
                        "contrast",
                        "error",
                        id,
                        "文字对比度 \{ratio.to_string()} 低于 WCAG AA 4.5:1",
                        "调整 text_color 或背景色以提高对比度",
                      ),
                    )
                  }
                }
                // L3: 间距一致性（子节点间距应统一）
                if is_frame_kind(n) && n.children.length() > 1 {
                  match n.layout {
                    Some(l) =>
                      if l.gap < 4.0 && n.children.length() > 2 {
                        lints.push(
                          lint_json(
                            "spacing",
                            "info",
                            id,
                            "容器内 \{n.children.length()} 个子元素间距仅 \{l.gap}，可能过于紧凑",
                            "建议间距 ≥ 8（令牌 md）",
                          ),
                        )
                      }
                    None => ()
                  }
                }
                // L4: 空容器
                if is_frame_kind(n) &&
                  n.children.length() == 0 &&
                  n.component != "divider" {
                  lints.push(
                    lint_json(
                      "empty_container",
                      "warning",
                      id,
                      "容器「\{n.name}」无子元素",
                      "添加内容或删除空容器",
                    ),
                  )
                }
              }
              None => ()
            }
          }
          None => ()
        }
      }
      Ok("[\{join_str4(lints)}]")
    }
  }
}

///|
fn lint_json(
  rule : String,
  severity : String,
  node_id : String,
  msg : String,
  suggestion : String,
) -> String {
  "{\"rule\":\"\{rule}\",\"severity\":\"\{severity}\",\"node_id\":\"\{node_id}\",\"message\":\"\{msg}\",\"suggestion\":\"\{suggestion}\"}"
}

///|
/// WCAG 相对亮度
fn relative_luminance(hex : String) -> Double {
  let r = hex_val(hex, 0) / 255.0
  let g = hex_val(hex, 2) / 255.0
  let b = hex_val(hex, 4) / 255.0
  let f = fn(c : Double) -> Double {
    if c <= 0.03928 {
      c / 12.92
    } else {
      Double::pow((c + 0.055) / 1.055, 2.4)
    }
  }
  0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
}

///|
fn hex_val(hex : String, offset : Int) -> Double {
  let body = if hex.length() > 0 && hex.get_char(0) == Some('#') {
    hex.substring(start=1)
  } else {
    hex
  }
  if body.length() < offset + 2 {
    return 128.0
  }
  let hi = hex_digit_val(body.get_char(offset))
  let lo = hex_digit_val(body.get_char(offset + 1))
  (hi * 16 + lo).to_double()
}

///|
fn hex_digit_val(c : Char?) -> Int {
  match c {
    Some(ch) => {
      let code = ch.to_int()
      if code >= 48 && code <= 57 {
        code - 48
      } else if code >= 97 && code <= 102 {
        code - 87
      } else if code >= 65 && code <= 70 {
        code - 55
      } else {
        8
      }
    }
    None => 8
  }
}

///|
/// WCAG 对比度
pub fn contrast_ratio(fg : String, bg : String) -> Double {
  let l1 = relative_luminance(fg)
  let l2 = relative_luminance(bg)
  let lighter = if l1 > l2 { l1 } else { l2 }
  let darker = if l1 > l2 { l2 } else { l1 }
  (lighter + 0.05) / (darker + 0.05)
}

// ---------------------------------------------------------------------------
// 修复建议
// ---------------------------------------------------------------------------

///|
/// 针对不崩谓词违规给出可执行的修复补丁
pub fn Project::suggest_fix(
  self : Project,
  artboard~ : String,
  node_id~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let violations = validate(ab.doc)
      let targeted : Array[String] = []
      for v in violations.iter() {
        if v.node_id == node_id {
          let suggestion : String = match v.predicate {
            ContainedInParent =>
              "缩小 width/height 或改用 Fill（自适应父容器），或增大父容器尺寸"
            NoSiblingOverlap =>
              "调整 x/y 位置避免与兄弟重叠，或改用栈布局自动排列"
            ConstraintSolvable =>
              "检查尺寸规格组合（Fill 需有界父容器），简化为 Fixed"
            _ => "检查节点结构"
          }
          targeted.push(
            "{\"predicate\":\"\{v.predicate.name()}\",\"node_id\":\"\{v.node_id}\",\"detail\":\"\{v.detail}\",\"fix\":\"\{suggestion}\"}",
          )
        }
      }
      if targeted.length() == 0 {
        Ok("{\"ok\":true,\"message\":\"节点 \{node_id} 无需修复\"}")
      } else {
        Ok("{\"ok\":false,\"fixes\":[\{join_str4(targeted)}]}")
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 项目导出
// ---------------------------------------------------------------------------

///|
pub fn Project::export_svg(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) =>
      Ok(
        render_svg(
          ab.doc,
          surface=self.tokens.resolve_color("surface"),
          frame=self.tokens.resolve_color("outline"),
        ),
      )
  }
}

///|
fn sanitize_id(name : String) -> String {
  let sb = StringBuilder::new()
  for c in name.iter() {
    let code = c.to_int()
    if (code >= 97 && code <= 122) || (code >= 48 && code <= 57) || code == 95 {
      sb.write_char(c)
    } else if code >= 65 && code <= 90 {
      sb.write_char(Char::from_int(code + 32))
    } else {
      sb.write_char('_')
    }
  }
  sb.to_string()
}
