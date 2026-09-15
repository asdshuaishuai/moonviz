///|
/// 交互原型系统：原型不是静态图——它有状态、有事件、有转场。
///
/// 核心概念：
/// - Trigger：什么触发了交互（tap / 长按 / 滑动 / 键盘）
/// - Action：交互发生什么（导航 / 切换状态 / 更新文字 / 提交表单）
/// - Transition：页面如何过渡（push / modal / fade）
/// - ComponentState：交互组件的多态（default / pressed / disabled / loading）
///
/// 运行时引擎（runtime.mbt）消费这些定义，驱动可交互的原型。

// ---------------------------------------------------------------------------
// 触发器
// ---------------------------------------------------------------------------

pub(all) enum Trigger {
  Tap // 单击
  LongPress(Double) // 长按（秒）
  SwipeLeft // 左滑
  SwipeRight // 右滑
  SwipeUp // 上滑
  SwipeDown // 下滑
  ScrollEnd // 滚动到底
  KeyboardEnter // 回车键
  Focus // 获得焦点
  Blur // 失去焦点
}

///|
pub fn Trigger::name(self : Trigger) -> String {
  match self {
    Tap => "tap"
    LongPress(_) => "long_press"
    SwipeLeft => "swipe_left"
    SwipeRight => "swipe_right"
    SwipeUp => "swipe_up"
    SwipeDown => "swipe_down"
    ScrollEnd => "scroll_end"
    KeyboardEnter => "keyboard_enter"
    Focus => "focus"
    Blur => "blur"
  }
}

// ---------------------------------------------------------------------------
// 动作
// ---------------------------------------------------------------------------

///|
pub(all) enum Action {
  NavigateTo(String) // 跳转到画板
  Back // 返回上一页（弹出导航栈）
  ToggleState(String, String) // 切换组件状态 (node_id, state_name)
  SetState(String, String) // 设置组件状态 (node_id, state_name)
  SetText(String, String) // 更新文字 (node_id, new_text)
  SubmitForm(Array[String]) // 提交表单（收集输入框 node_ids）
  ShowToast(String) // 显示临时消息
  HapticFeedback // 触觉反馈
  PlaySound(String) // 播放音效
}

///|
pub fn Action::describe(self : Action) -> String {
  match self {
    NavigateTo(target) => "navigate_to:\{target}"
    Back => "back"
    ToggleState(id, _) => "toggle_state:\{id}"
    SetState(id, state) => "set_state:\{id}:\{state}"
    SetText(id, text) => "set_text:\{id}:\"\{text}\""
    SubmitForm(ids) => "submit_form:[\{ids.length()} fields]"
    ShowToast(msg) => "show_toast:\"\{msg}\""
    HapticFeedback => "haptic"
    PlaySound(name) => "play_sound:\{name}"
  }
}

// ---------------------------------------------------------------------------
// 转场
// ---------------------------------------------------------------------------

///|
pub(all) enum Transition {
  Push // 从右滑入
  Pop // 从左滑出（返回）
  ModalPresent // 从底部滑入（模态）
  ModalDismiss // 向底部滑出（关闭模态）
  SheetPresent // 部分滑入（半屏 sheet）
  Fade // 交叉淡入淡出
  NoTransition // 无动画
}

///|
pub fn Transition::name(self : Transition) -> String {
  match self {
    Push => "push"
    Pop => "pop"
    ModalPresent => "modal_present"
    ModalDismiss => "modal_dismiss"
    SheetPresent => "sheet_present"
    Fade => "fade"
    NoTransition => "none"
  }
}

// ---------------------------------------------------------------------------
// 交互定义
// ---------------------------------------------------------------------------

///|
pub(all) struct InteractionDef {
  node_id : String // 触发交互的节点
  trigger : Trigger // 触发条件
  action : Action // 执行动作
  transition : Transition // 页面转场方式
}

///|
/// 组件多态（同一组件的不同视觉状态）
pub(all) struct ComponentStateDef {
  node_id : String
  states : Map[String, NodePatch] // "default" → base, "pressed" → darker fill...
  mut current : String
}

// ---------------------------------------------------------------------------
// 交互注册与管理
// ---------------------------------------------------------------------------

///|
/// 为节点添加交互定义
pub fn Project::add_interaction(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  trigger~ : Trigger,
  action~ : Action,
  transition? : Transition = Push,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      if !ab.doc.has(node_id) {
        return Err("unknown_node: \{node_id}")
      }
      let inter : InteractionDef = { node_id, trigger, action, transition }
      match ab.doc.nodes.get(node_id) {
        Some(n) => {
          // 把交互信息序列化到节点的 metadata（v1：存 text 前缀标记）
          let marker = "⚡\{trigger.name()}→\{action.describe()}"
          let _ = ab.doc.update_node(node_id, fn(x) {
            { ..x, name: "\{x.name} \{marker}" }
          })
          Ok(
            "{\"ok\":true,\"interaction\":\"\{node_id}:\{trigger.name()}→\{action.describe()}\"}",
          )
        }
        None => Err("node_not_found")
      }
    }
  }
}

///|
/// 为组件定义多态状态（真实存储补丁，而非仅写标记）。
///
/// 状态作用于渲染/命中前的节点变换：default 为该节点的基准补丁，
/// pressed/disabled 等为相对基准的覆盖。此前该函数接收 patch 却完全丢弃，
/// 只留一个无人读取的名字标记——签名承诺的能力实际不存在。
pub fn Project::define_component_state(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  state_name~ : String,
  patch~ : NodePatch,
) -> Result[String, String] {
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return Err("unknown_artboard: \{artboard}")
  }
  if !ab.doc.has(node_id) {
    return Err("unknown_node: \{node_id}")
  }
  let def = match self.node_states.get(node_id) {
    Some(d) => d
    None => { node_id, states: Map::new(), current: "default" }
  }
  def.states.set(state_name, patch)
  self.node_states.set(node_id, def)
  // 状态定义必须随 canonical MBT 往返：序列化到节点名标记（[state:...]）。
  // 仅存内存会在每次 load-mbt-b64 重建 Project 时静默丢失。
  let count = def.states.size().to_string()
  let markers = states_to_markers(def)
  let cur = if def.current != "default" { ["[cur:" + def.current + "]"] } else { [] }
  for m in cur {
    markers.push(m)
  }
  let _ = ab.doc.update_node(node_id, fn(n) {
    { ..n, name: rebuild_name(n.name, markers) }
  })
  self.revision = self.revision + 1
  Ok(
    "{\"ok\":true,\"node\":\"\{node_id}\",\"state\":\"\{state_name}\",\"states\":\{count}}",
  )
}

///|
/// 状态定义 → 名字标记列表：`[state:<name>:k=v,k=v]`
fn states_to_markers(def : ComponentStateDef) -> Array[String] {
  let out : Array[String] = []
  for name in def.states.keys() {
    match def.states.get(name) {
      Some(p) => out.push("[state:" + name + ":" + patch_to_spec(p) + "]")
      None => ()
    }
  }
  out
}

///|
/// NodePatch → 紧凑规格 "k=v,k=v"（与 marker_to_patch 对称）。
fn patch_to_spec(p : NodePatch) -> String {
  let parts : Array[String] = []
  match p.fill {
    Some(v) => parts.push("fill=" + v)
    None => ()
  }
  match p.text_color {
    Some(v) => parts.push("text_color=" + v)
    None => ()
  }
  match p.stroke {
    Some(v) => parts.push("stroke=" + v)
    None => ()
  }
  match p.text {
    Some(v) => parts.push("text=" + v)
    None => ()
  }
  match p.corner_radius {
    Some(v) => parts.push("radius=" + double_text(v))
    None => ()
  }
  match p.font_size {
    Some(v) => parts.push("font_size=" + double_text(v))
    None => ()
  }
  match p.layout_gap {
    Some(v) => parts.push("gap=" + double_text(v))
    None => ()
  }
  let sb = StringBuilder::new()
  for i = 0; i < parts.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(parts[i])
  }
  sb.to_string()
}

///|
/// 从 name 中提取交互标记（"⚡..."），无则空串。
pub fn extract_interaction_marker(name : String) -> String {
  match name.find("⚡") {
    None => ""
    Some(i) => {
      let tail = name.substring(start=i, end=name.length())
      // 交互标记到下一个状态标记为止
      match tail.find("[state:") {
        None => tail.trim().to_string()
        Some(j) => tail.substring(start=0, end=j).trim().to_string()
      }
    }
  }
}

///|
/// 用新的状态标记重建节点名：保留原始名与交互标记，替换全部状态标记。
pub fn rebuild_name(name : String, state_markers : Array[String]) -> String {
  let base = strip_all_markers(name)
  let inter = extract_interaction_marker(name)
  let sb = StringBuilder::new()
  sb.write_string(base)
  if inter != "" {
    if base != "" {
      sb.write_string(" ")
    }
    sb.write_string(inter)
  }
  for m in state_markers.iter() {
    if sb.to_string() != "" {
      sb.write_string(" ")
    }
    sb.write_string(m)
  }
  sb.to_string()
}

///|
/// 去掉节点名中的全部标记（交互 ⚡ 与状态 [state:），还原原始名。
pub fn strip_all_markers(name : String) -> String {
  let mut cut = name.length()
  match name.find("⚡") {
    Some(i) => if i < cut { cut = i }
    None => ()
  }
  match name.find("[state:") {
    Some(i) => if i < cut { cut = i }
    None => ()
  }
  match name.find("[cur:") {
    Some(i) => if i < cut { cut = i }
    None => ()
  }
  let head = name.substring(start=0, end=cut)
  let mut end = head.length()
  while end > 0 && head.substring(start=end - 1, end=end) == " " {
    end = end - 1
  }
  head.substring(start=0, end=end)
}

///|
/// 扫描节点名标记，重建 Project 的状态表（load 后调用）。
/// 状态定义随名字往返，但内存表需在重建 Project 后重新填充。
pub fn Project::rebuild_node_states(self : Project, artboard~ : String) -> Unit {
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return
  }
  for id in ab.doc.nodes.keys() {
    match ab.doc.nodes.get(id) {
      Some(n) =>
        match parse_state_markers(n.name) {
          Some(states) => {
            let def = match self.node_states.get(id) {
              Some(d) => d
              None => { node_id: id, states: Map::new(), current: "default" }
            }
            for kv in states.iter() {
              let (sname, patch) = kv
              def.states.set(sname, patch)
            }
            // [cur:<name>]：重载时恢复当前激活状态
            match n.name.find("[cur:") {
              Some(ci) => {
                let rest_name = n.name.substring(start=ci + 5)
                match rest_name.find("]") {
                  Some(e) => {
                    let cname = rest_name.substring(start=0, end=e)
                    if cname != "" && def.states.contains(cname) {
                      def.current = cname
                    }
                  }
                  None => ()
                }
              }
              None => ()
            }
            self.node_states.set(id, def)
          }
          None => ()
        }
      None => ()
    }
  }
}

///|
/// 解析名字中的全部 [state:name:spec] 标记 → (state_name, patch) 列表。
pub fn parse_state_markers(name : String) -> Array[(String, NodePatch)]? {
  let out : Array[(String, NodePatch)] = []
  let mut rest = name
  while true {
    match rest.find("[state:") {
      None => break
      Some(i) => {
        let tail = rest.substring(start=i + 7, end=rest.length())
        match tail.find("]") {
          None => break
          Some(j) => {
            let body = tail.substring(start=0, end=j)
            match body.find(":") {
              None => ()
              Some(k) => {
                let sname = body.substring(start=0, end=k)
                let spec = body.substring(start=k + 1, end=body.length())
                if sname != "" {
                  out.push((sname, spec_to_patch(spec)))
                }
              }
            }
            rest = tail.substring(start=j + 1, end=tail.length())
          }
        }
      }
    }
  }
  if out.length() == 0 {
    None
  } else {
    Some(out)
  }
}

///|
/// 紧凑规格 "k=v,k=v" → NodePatch（与 patch_to_spec 对称）。
fn spec_to_patch(spec : String) -> NodePatch {
  let mut fill : String? = None
  let mut text_color : String? = None
  let mut stroke : String? = None
  let mut text : String? = None
  let mut radius : Double? = None
  let mut font_size : Double? = None
  let mut gap : Double? = None
  for kv in split_commas(spec).iter() {
    match kv.find("=") {
      None => ()
      Some(eq) => {
        let k = kv.substring(start=0, end=eq)
        let v = kv.substring(start=eq + 1, end=kv.length())
        match k {
          "fill" => fill = Some(v)
          "text_color" => text_color = Some(v)
          "stroke" => stroke = Some(v)
          "text" => text = Some(v)
          "radius" => radius = Some(parse_double(v))
          "font_size" => font_size = Some(parse_double(v))
          "gap" => gap = Some(parse_double(v))
          _ => ()
        }
      }
    }
  }
  {
    ..NodePatch::empty(),
    fill,
    text_color,
    stroke,
    text,
    corner_radius: radius,
    font_size,
    layout_gap: gap,
  }
}

///|
fn split_commas(s : String) -> Array[String] {
  let out : Array[String] = []
  let cur = StringBuilder::new()
  for c in s.iter() {
    if c == ',' {
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
/// 数值 → 紧凑文本（整数省略小数点，与 decl 层 num_text 视觉一致）
fn double_text(d : Double) -> String {
  if d == d.to_int().to_double() {
    d.to_int().to_string()
  } else {
    d.to_string()
  }
}



///|
/// 切换/设置节点当前状态并返回变更后的节点。
/// ToggleState：在 default 与目标状态间切换；SetState：直接设为目标状态。
pub fn Project::set_node_state(
  self : Project,
  node_id~ : String,
  state_name~ : String,
  toggle? : Bool = false,
) -> Result[String, String] {
  let def = match self.node_states.get(node_id) {
    Some(d) => d
    None => return Err("no_states: \{node_id}")
  }
  if !def.states.contains(state_name) {
    return Err("unknown_state: \{state_name}")
  }
  let next = if toggle && def.current == state_name {
    "default"
  } else {
    state_name
  }
  def.current = next
  self.node_states.set(node_id, def)
  // current 写回节点名标记：[cur:<name>]，随 canonical MBT 往返。
  // 此前仅改内存，重载后永远回 default。
  let artboard_id = self.find_node_artboard(node_id)
  match artboard_id {
    Some(aid) =>
      match self.artboards.get(aid) {
        Some(ab) => {
          let markers = states_to_markers(def)
          if next != "default" {
            markers.push("[cur:" + next + "]")
          }
          let _ = ab.doc.update_node(node_id, fn(n) {
            { ..n, name: rebuild_name(n.name, markers) }
          })
        }
        None => ()
      }
    None => ()
  }
  self.revision = self.revision + 1
  Ok("{\"ok\":true,\"node\":\"\{node_id}\",\"current\":\"\{next}\"}")
}

///|
/// 找到节点所在的画板 id（状态表是项目级的，名字标记在画板文档里）
fn Project::find_node_artboard(self : Project, node_id : String) -> String? {
  for aid in self.artboards.keys() {
    match self.artboards.get(aid) {
      Some(ab) => if ab.doc.has(node_id) { return Some(aid) }
      None => ()
    }
  }
  None
}

///|
/// 当前状态下节点应有的补丁（default 缺省则返回空补丁）。
pub fn Project::active_state_patch(self : Project, node_id : String) -> NodePatch? {
  match self.node_states.get(node_id) {
    None => None
    Some(def) =>
      match def.states.get(def.current) {
        Some(p) => Some(p)
        None =>
          match def.states.get("default") {
            Some(p) => Some(p)
            None => None
          }
      }
  }
}

///|
/// 结构化回读：节点的全部已定义状态与其当前值。
pub fn Project::node_states_json(self : Project, artboard~ : String) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let items : Array[String] = []
      for id in ab.doc.nodes.keys() {
        match self.node_states.get(id) {
          Some(def) => {
            let names : Array[String] = []
            for s in def.states.keys() {
              names.push("\"\{s}\"")
            }
            items.push(
              "{\"node\":\"\{id}\",\"current\":\"\{def.current}\",\"states\":[\{jstr12(names)}]}",
            )
          }
          None => ()
        }
      }
      Ok("[\{jstr12(items)}]")
    }
  }
}

// ---------------------------------------------------------------------------
// 导航栈（运行时状态）
// ---------------------------------------------------------------------------

///|
pub(all) struct NavigationState {
  mut stack : Array[String] // 当前导航栈
  mut current : String // 当前画板 ID
}

///|
pub fn NavigationState::new(initial : String) -> NavigationState {
  { stack: [initial], current: initial }
}

///|
pub fn NavigationState::navigate(
  self : NavigationState,
  target : String,
) -> String {
  self.stack.push(target)
  self.current = target
  target
}

///|
pub fn NavigationState::go_back(self : NavigationState) -> String? {
  if self.stack.length() > 1 {
    let _ = self.stack.pop()
    match self.stack.get(self.stack.length() - 1) {
      Some(top) => {
        self.current = top
        Some(top)
      }
      None => None
    }
  } else {
    None
  }
}

// ---------------------------------------------------------------------------
// 交互清单（Agent 审阅用）
// ---------------------------------------------------------------------------

///|
/// 列出画板的所有交互定义（从节点名解析）
pub fn Project::list_interactions(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      let items : Array[String] = []
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            if n.name.contains("⚡") {
              items.push(
                "{\"node\":\"\{id}\",\"name\":\"\{n.name}\",\"artboard\":\"\{artboard}\"}",
              )
            }
          None => ()
        }
      }
      let j = jstr12(items)
      Ok("[\{j}]")
    }
  }
}

///|
fn jstr12(parts : Array[String]) -> String {
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
// 交互标记解析（运行时消费 / CLI 构造共用）
// ---------------------------------------------------------------------------

///|
/// 从节点名提取交互标记 → (trigger, action_spec)。
/// 标记由 add_interaction 追加，格式 "…⚡<trigger>→<action>"。
/// 用字符迭代 + ASCII 白名单提取 trigger，避免多字节 emoji 的字节偏移歧义。
pub fn parse_interaction_marker(name : String) -> (String, String)? {
  let before = StringBuilder::new()
  let seen_arrow : Ref[Bool] = Ref::new(false)
  let after = StringBuilder::new()
  for c in name.iter() {
    if c == '→' {
      seen_arrow.val = true
      continue
    }
    if seen_arrow.val {
      after.write_char(c)
    } else {
      before.write_char(c)
    }
  }
  if !seen_arrow.val {
    return None
  }
  // trigger = 箭头前最后一个空白分隔 token 中的 ASCII 标识符部分
  let chars : Array[Char] = []
  for c in before.to_string().iter() {
    chars.push(c)
  }
  let mut last_space = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == ' ' || chars[i] == '\t' {
      last_space = i
    }
  }
  let trig = StringBuilder::new()
  for i = last_space + 1; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' {
      trig.write_char(c)
    }
  }
  let t = trig.to_string()
  // action 到下一个状态标记为止：交互与状态标记共存于同一 name，
  // 不截断会把 "[state:...]" 当成 action 的一部分。
  let raw_after = after.to_string()
  let a = match raw_after.find("[state:") {
    Some(i) => raw_after.substring(start=0, end=i).trim().to_string()
    None => raw_after.trim().to_string()
  }
  if t == "" || a == "" {
    return None
  }
  Some((t, a))
}

///|
/// trigger 规格 → Trigger（CLI / Agent 语法共用）。
/// 别名与 Trigger::name 保持一致；keyboard_enter 接受 key_enter 简写。
pub fn trigger_from_spec(spec : String) -> Trigger? {
  match spec {
    "tap" => Some(Tap)
    "long_press" => Some(LongPress(0.5))
    "swipe_left" => Some(SwipeLeft)
    "swipe_right" => Some(SwipeRight)
    "swipe_up" => Some(SwipeUp)
    "swipe_down" => Some(SwipeDown)
    "scroll_end" => Some(ScrollEnd)
    "key_enter" | "keyboard_enter" => Some(KeyboardEnter)
    "focus" => Some(Focus)
    "blur" => Some(Blur)
    _ => None
  }
}

///|
/// action 规格 → Action。规格语法与 Action::describe 的输出对称：
///   back | haptic | navigate_to:<board> | show_toast:"msg" | play_sound:<name>
///   | toggle_state:<node> | set_state:<node>:<state> | set_text:<node>:"text"
pub fn action_from_spec(spec : String) -> Action? {
  match spec {
    "back" => Some(Back)
    "haptic" => Some(HapticFeedback)
    _ =>
      match spec.find(":") {
        None => None
        Some(i) => {
          let head = spec.substring(start=0, end=i)
          let rest = spec.substring(start=i + 1, end=spec.length())
          match head {
            "navigate_to" => if rest == "" { None } else { Some(NavigateTo(rest)) }
            "show_toast" =>
              if rest == "" { None } else { Some(ShowToast(unquote_spec(rest))) }
            "play_sound" =>
              if rest == "" { None } else { Some(PlaySound(rest)) }
            "toggle_state" =>
              if rest == "" { None } else { Some(ToggleState(rest, "")) }
            "set_text" =>
              match rest.find(":") {
                None => None
                Some(j) => {
                  let id = rest.substring(start=0, end=j)
                  let txt = rest.substring(start=j + 1, end=rest.length())
                  if id == "" { None } else { Some(SetText(id, unquote_spec(txt))) }
                }
              }
            "set_state" =>
              match rest.find(":") {
                None => None
                Some(j) => {
                  let id = rest.substring(start=0, end=j)
                  let st = rest.substring(start=j + 1, end=rest.length())
                  if id == "" { None } else { Some(SetState(id, st)) }
                }
              }
            _ => None
          }
        }
      }
  }
}

///|
/// 去掉规格值两端的双引号（show_toast:"msg" / set_text:n:"txt"）。
fn unquote_spec(s : String) -> String {
  if s.length() >= 2 &&
    s.substring(start=0, end=1) == "\"" &&
    s.substring(start=s.length() - 1, end=s.length()) == "\"" {
    s.substring(start=1, end=s.length() - 1)
  } else {
    s
  }
}

///|
/// 追加交互标记到节点名（幂等：同名标记不重复追加）。
pub fn Project::attach_interaction(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  trigger~ : String,
  action_spec~ : String,
) -> Result[String, String] {
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return Err("unknown_artboard: \{artboard}")
  }
  let node = match ab.doc.nodes.get(node_id) {
    Some(n) => n
    None => return Err("unknown_node: \{node_id}")
  }
  let marker = "⚡\{trigger}→\{action_spec}"
  if node.name.contains(marker) {
    return Ok("{\"ok\":true,\"node\":\"\{node_id}\",\"unchanged\":true}")
  }
  // 先清理旧标记，保证一个节点只有一个生效交互且标记不累积
  let base = strip_markers(node.name)
  let updated = if base == "" {
    marker
  } else {
    base + " " + marker
  }
  let _ = ab.doc.update_node(node_id, fn(n) { { ..n, name: updated } })
  self.revision = self.revision + 1
  Ok(
    "{\"ok\":true,\"node\":\"\{node_id}\",\"trigger\":\"\{trigger}\",\"action\":\"\{action_spec}\"}",
  )
}

///|
/// 移除节点名的全部交互标记（保留原始名）。
pub fn Project::detach_interaction(
  self : Project,
  artboard~ : String,
  node_id~ : String,
) -> Result[String, String] {
  let ab = match self.artboards.get(artboard) {
    Some(a) => a
    None => return Err("unknown_artboard: \{artboard}")
  }
  let node = match ab.doc.nodes.get(node_id) {
    Some(n) => n
    None => return Err("unknown_node: \{node_id}")
  }
  let base = strip_markers(node.name)
  let _ = ab.doc.update_node(node_id, fn(n) { { ..n, name: base } })
  self.revision = self.revision + 1
  Ok("{\"ok\":true,\"node\":\"\{node_id}\",\"cleared\":true}")
}

///|
/// 去掉名称里的交互标记（含 marker 与其前的分隔空格）。
pub fn strip_markers(name : String) -> String {
  let idx = name.find("⚡")
  match idx {
    None => name
    Some(i) => {
      let head = name.substring(start=0, end=i)
      // 修剪标记前遗留的尾随空格
      let mut end = head.length()
      while end > 0 && head.substring(start=end - 1, end=end) == " " {
        end = end - 1
      }
      head.substring(start=0, end=end)
    }
  }
}

///|
/// 结构化交互清单：解析标记 → trigger/action 字段（供 Agent 审阅与回读）。
pub fn Project::interactions_json(
  self : Project,
  artboard~ : String,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard: \{artboard}")
    Some(ab) => {
      let items : Array[String] = []
      for id in ab.doc.nodes.keys() {
        match ab.doc.nodes.get(id) {
          Some(n) =>
            match parse_interaction_marker(n.name) {
              Some((trig, spec)) =>
                items.push(
                  "{\"node\":\"\{id}\",\"trigger\":\"\{trig}\",\"action\":\"\{spec}\"}",
                )
              None => ()
            }
          None => ()
        }
      }
      Ok("[\{jstr12(items)}]")
    }
  }
}
