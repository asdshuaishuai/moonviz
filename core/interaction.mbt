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
  current : String
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
/// 为组件定义多态状态
pub fn Project::define_component_state(
  self : Project,
  artboard~ : String,
  node_id~ : String,
  state_name~ : String,
  patch~ : NodePatch,
) -> Result[String, String] {
  match self.artboards.get(artboard) {
    None => Err("unknown_artboard")
    Some(ab) => {
      if !ab.doc.has(node_id) {
        return Err("unknown_node: \{node_id}")
      }
      // v1: 将状态信息编码到节点名（简化存储）
      let marker = "[state:\{state_name}]"
      let _ = ab.doc.update_node(node_id, fn(x) {
        { ..x, name: "\{x.name}\{marker}" }
      })
      Ok("{\"ok\":true,\"state\":\"\{node_id}:\{state_name}\"}")
    }
    None => Err("unknown_artboard")
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
  let a = after.to_string()
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
